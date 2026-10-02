<?php
/**
 * Finds where the existing startup plugin keeps its data and reads it.
 *
 * Read-only: these classes only run SELECT queries and WordPress getters.
 * Two kinds of storage are supported:
 *
 * - A custom post type (startups as posts, details in post meta and
 *   taxonomies). Detected by a post type whose URL base is /startups/ or
 *   whose name contains "startup".
 * - A custom database table whose name contains "startup".
 *
 * The detected source can be overridden with the
 * `allbiohub_app_api_source` filter (see readme).
 *
 * @package AllBioHub_App_API
 */

defined( 'ABSPATH' ) || exit;

interface AllBioHub_App_API_Source {
	/** Human-readable description for the settings screen. */
	public function describe();

	/**
	 * Raw records, each with id, slug, name, link, created_at (GMT),
	 * updated_at (GMT), optional logo and fields (normalised key => value).
	 *
	 * @return array[]
	 */
	public function records();

	/** Image URL for an attachment id, for logos stored as ids. */
	public function image_url( $attachment_id );
}

final class AllBioHub_App_API_Sources {

	/**
	 * Picks the startup data source, or null when none is found. When more
	 * than one place looks like startups (for example a "startup claims"
	 * post type next to the real directory table), the one with the most
	 * live startups wins.
	 */
	public static function detect() {
		$source = apply_filters( 'allbiohub_app_api_source', null );
		if ( $source instanceof AllBioHub_App_API_Source ) {
			return $source;
		}
		$best       = null;
		$best_count = -1;
		foreach ( self::candidates() as $candidate ) {
			$count = count( $candidate->records() );
			if ( $count > $best_count ) {
				$best       = $candidate;
				$best_count = $count;
			}
		}
		return $best;
	}

	/** Every post type and table that may hold startups. */
	public static function candidates() {
		$candidates = array();
		foreach ( self::find_post_types() as $post_type ) {
			$candidates[] = new AllBioHub_App_API_Post_Type_Source( $post_type );
		}
		foreach ( self::find_tables() as $table ) {
			$candidates[] = new AllBioHub_App_API_Table_Source( $table['table'], $table['columns'] );
		}
		return $candidates;
	}

	/** Registered post types that may hold startups, likeliest first. */
	public static function find_post_types() {
		$found = array();
		foreach ( get_post_types( array(), 'objects' ) as $type ) {
			if ( in_array( $type->name, array( 'post', 'page', 'attachment', 'revision', 'nav_menu_item' ), true ) ) {
				continue;
			}
			$slug  = is_array( $type->rewrite ) && isset( $type->rewrite['slug'] ) ? trim( $type->rewrite['slug'], '/' ) : '';
			$score = 0;
			if ( 'startups' === $slug || 'startup' === $slug ) {
				$score += 3;
			}
			if ( false !== strpos( $type->name, 'startup' ) ) {
				$score += 2;
			}
			if ( $type->public ) {
				++$score;
			}
			if ( $score >= 2 ) {
				$found[ $type->name ] = $score;
			}
		}
		arsort( $found );
		return array_keys( $found );
	}

	/** The likeliest startup post type, or null. */
	public static function find_post_type() {
		$types = self::find_post_types();
		return $types ? $types[0] : null;
	}

	/** Custom tables that may hold startups, with their columns. */
	public static function find_tables() {
		global $wpdb;
		$found  = array();
		foreach ( self::table_names() as $table ) {
			$columns = $wpdb->get_col( 'SHOW COLUMNS FROM `' . esc_sql( $table ) . '`' );
			$cols    = array_map( 'strtolower', (array) $columns );
			$has     = function ( $names ) use ( $cols ) {
				return (bool) array_intersect( $names, $cols );
			};
			// A main startup table has an id, a name and a slug (not a
			// table of claims, founders or payments).
			if ( ! in_array( 'id', $cols, true ) || ! $has( array( 'name', 'company_name', 'startup_name', 'title' ) ) || ! $has( array( 'slug', 'startup_slug', 'post_name' ) ) ) {
				continue;
			}
			$found[] = array(
				'table'   => $table,
				'columns' => $columns,
			);
		}
		return $found;
	}

	/**
	 * Tables whose names suggest a company directory: "startup", and the
	 * "companies", "directory" and "listings" names some directory plugins
	 * use.
	 */
	public static function table_names() {
		global $wpdb;
		$names = array();
		foreach ( array( 'startup', 'compan', 'director', 'listing' ) as $word ) {
			$like  = $wpdb->esc_like( $wpdb->prefix ) . '%' . $wpdb->esc_like( $word ) . '%';
			$names = array_merge( $names, (array) $wpdb->get_col( $wpdb->prepare( 'SHOW TABLES LIKE %s', $like ) ) );
		}
		return array_values( array_unique( $names ) );
	}

	/** The first startup table, or null. */
	public static function find_table() {
		$tables = self::find_tables();
		return $tables ? $tables[0] : null;
	}
}

final class AllBioHub_App_API_Post_Type_Source implements AllBioHub_App_API_Source {

	/** @var string */
	private $post_type;

	public function __construct( $post_type ) {
		$this->post_type = $post_type;
	}

	public function describe() {
		$object = get_post_type_object( $this->post_type );
		$label  = $object ? $object->labels->name : $this->post_type;
		/* translators: 1: post type label, 2: post type name. */
		return sprintf( __( 'Post type "%1$s" (%2$s)', 'allbiohub-app-api' ), $label, $this->post_type );
	}

	public function post_type() {
		return $this->post_type;
	}

	public function records() {
		$ids = get_posts(
			array(
				'post_type'        => $this->post_type,
				'post_status'      => 'publish',
				'has_password'     => false,
				'posts_per_page'   => -1,
				'fields'           => 'ids',
				'no_found_rows'    => true,
				'suppress_filters' => false,
			)
		);
		if ( ! $ids ) {
			return array();
		}
		update_meta_cache( 'post', $ids );
		$taxonomies = get_object_taxonomies( $this->post_type, 'objects' );
		update_object_term_cache( $ids, $this->post_type );

		$records = array();
		foreach ( $ids as $id ) {
			$post = get_post( $id );
			$raw  = array();
			foreach ( get_post_meta( $id ) as $key => $values ) {
				$raw[ $key ] = maybe_unserialize( count( $values ) === 1 ? $values[0] : $values );
			}
			foreach ( $taxonomies as $taxonomy ) {
				$terms = get_the_terms( $id, $taxonomy->name );
				if ( ! $terms || is_wp_error( $terms ) ) {
					continue;
				}
				$names = wp_list_pluck( $terms, 'name' );
				// Register under the taxonomy name and its URL base, so
				// "startup_industry" and ".../startups/industry/" both
				// match "industry".
				$raw[ $taxonomy->name ] = $names;
				if ( is_array( $taxonomy->rewrite ) && ! empty( $taxonomy->rewrite['slug'] ) ) {
					$parts                  = explode( '/', trim( $taxonomy->rewrite['slug'], '/' ) );
					$raw[ end( $parts ) ] = $names;
				}
			}
			$raw['post_excerpt'] = $post->post_excerpt;
			$raw['post_content'] = $post->post_content;

			$records[] = array(
				'id'         => $id,
				'slug'       => $post->post_name,
				'name'       => get_the_title( $post ),
				'link'       => get_permalink( $post ),
				'created_at' => $post->post_date_gmt,
				'updated_at' => $post->post_modified_gmt,
				'logo'       => get_the_post_thumbnail_url( $post, 'medium' ),
				'fields'     => AllBioHub_App_API_Mapper::normalize_fields( $raw ),
			);
		}
		return $records;
	}

	public function image_url( $attachment_id ) {
		$url = wp_get_attachment_image_url( $attachment_id, 'medium' );
		return $url ? $url : null;
	}
}

final class AllBioHub_App_API_Table_Source implements AllBioHub_App_API_Source {

	/** Columns that say whether a row is live on the website. */
	const VISIBILITY = array(
		'is_published' => array( '1' ),
		'published'    => array( '1' ),
		'is_approved'  => array( '1' ),
		'approved'     => array( '1' ),
		'post_status'  => array( 'publish' ),
	);

	/** @var string */
	private $table;
	/** @var string[] */
	private $columns;

	public function __construct( $table, array $columns ) {
		$this->table   = $table;
		$this->columns = $columns;
	}

	public function describe() {
		/* translators: %s: database table name. */
		return sprintf( __( 'Database table %s', 'allbiohub-app-api' ), $this->table );
	}

	public function records() {
		global $wpdb;
		$rows    = $wpdb->get_results( 'SELECT * FROM `' . esc_sql( $this->table ) . '`', ARRAY_A );
		$records = array();
		foreach ( (array) $rows as $row ) {
			$row = array_change_key_case( $row, CASE_LOWER );
			if ( ! $this->is_live( $row ) ) {
				continue;
			}
			$name = self::pick( $row, array( 'name', 'company_name', 'startup_name', 'title' ) );
			$slug = self::pick( $row, array( 'slug', 'startup_slug', 'post_name' ) );
			$link = self::pick( $row, array( 'permalink', 'profile_url' ) );
			if ( ! $link && $slug ) {
				$link = home_url( '/startups/' . rawurlencode( $slug ) . '/' );
			}
			$records[] = array(
				'id'         => (int) $row['id'],
				'slug'       => $slug,
				'name'       => $name,
				'link'       => $link,
				'created_at' => self::pick( $row, array( 'created_at', 'date_created', 'created', 'submitted_at', 'date_added' ) ),
				'updated_at' => self::pick( $row, array( 'updated_at', 'date_modified', 'modified', 'last_updated', 'updated' ) ),
				'fields'     => AllBioHub_App_API_Mapper::normalize_fields( $row ),
			);
		}
		return $records;
	}

	/**
	 * Rows hidden on the website (pending, rejected, drafts) stay hidden.
	 * A generic "status" column is only used when it holds moderation
	 * values, since it may otherwise be the company's status (Active, …).
	 */
	private function is_live( array $row ) {
		foreach ( self::VISIBILITY as $column => $live ) {
			if ( array_key_exists( $column, $row ) ) {
				return in_array( strtolower( (string) $row[ $column ] ), $live, true );
			}
		}
		foreach ( array( 'moderation_status', 'approval_status', 'listing_status', 'status' ) as $column ) {
			if ( ! array_key_exists( $column, $row ) ) {
				continue;
			}
			$value = strtolower( (string) $row[ $column ] );
			if ( in_array( $value, array( 'pending', 'draft', 'rejected', 'trash', 'deleted', 'private', 'spam', 'unpublished', 'hidden', 'inactive_listing' ), true ) ) {
				return false;
			}
		}
		return true;
	}

	private static function pick( array $row, array $keys ) {
		foreach ( $keys as $key ) {
			if ( isset( $row[ $key ] ) && '' !== trim( (string) $row[ $key ] ) ) {
				return $row[ $key ];
			}
		}
		return null;
	}

	public function image_url( $attachment_id ) {
		$url = wp_get_attachment_image_url( $attachment_id, 'medium' );
		return $url ? $url : null;
	}
}
