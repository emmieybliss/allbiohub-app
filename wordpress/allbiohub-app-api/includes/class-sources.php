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

	/** Picks the startup data source, or null when none is found. */
	public static function detect() {
		$source = apply_filters( 'allbiohub_app_api_source', null );
		if ( $source instanceof AllBioHub_App_API_Source ) {
			return $source;
		}
		$post_type = self::find_post_type();
		if ( $post_type ) {
			return new AllBioHub_App_API_Post_Type_Source( $post_type );
		}
		$table = self::find_table();
		if ( $table ) {
			return new AllBioHub_App_API_Table_Source( $table['table'], $table['columns'] );
		}
		return null;
	}

	/** A registered post type that holds startups. */
	public static function find_post_type() {
		$best = null;
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
			if ( $score >= 2 && ( ! $best || $score > $best[0] ) ) {
				$best = array( $score, $type->name );
			}
		}
		return $best ? $best[1] : null;
	}

	/** A custom table that holds startups, with its columns. */
	public static function find_table() {
		global $wpdb;
		$like   = $wpdb->esc_like( $wpdb->prefix ) . '%startup%';
		$tables = $wpdb->get_col( $wpdb->prepare( 'SHOW TABLES LIKE %s', $like ) );
		$best   = null;
		foreach ( (array) $tables as $table ) {
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
			$count = (int) $wpdb->get_var( 'SELECT COUNT(*) FROM `' . esc_sql( $table ) . '`' );
			if ( ! $best || $count > $best['count'] ) {
				$best = array(
					'table'   => $table,
					'columns' => $columns,
					'count'   => $count,
				);
			}
		}
		return $best;
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
