<?php
/**
 * Plugin Name:       AllBioHub App API
 * Description:       Read-only startup directory API for the AllBioHub mobile app. Adds GET routes under /wp-json/allbiohub/v1/ and changes nothing else on the site.
 * Version:           1.0.2
 * Requires at least: 6.0
 * Requires PHP:      7.4
 * Author:            AllBioHub
 * License:           GPL-2.0-or-later
 * Text Domain:       allbiohub-app-api
 *
 * @package AllBioHub_App_API
 */

defined( 'ABSPATH' ) || exit;

define( 'ALLBIOHUB_APP_API_VERSION', '1.0.2' );

require_once __DIR__ . '/includes/class-mapper.php';
require_once __DIR__ . '/includes/class-directory.php';
require_once __DIR__ . '/includes/class-sources.php';
require_once __DIR__ . '/includes/class-rest.php';
require_once __DIR__ . '/includes/class-admin.php';

final class AllBioHub_App_API {

	/** Option: the API answers only after an admin has checked the preview and switched it on. */
	const OPTION_ENABLED = 'allbiohub_app_api_enabled';
	const CACHE_KEY      = 'allbiohub_app_api_startups_v2';
	const CACHE_TTL      = 600;

	public static function boot() {
		add_action( 'rest_api_init', array( 'AllBioHub_App_API_Rest', 'register' ) );
		AllBioHub_App_API_Admin::boot();

		// Keep the app in step with edits made on the website.
		add_action( 'save_post', array( __CLASS__, 'flush_for_post' ) );
		add_action( 'deleted_post', array( __CLASS__, 'flush_for_post' ) );
		add_action( 'trashed_post', array( __CLASS__, 'flush_for_post' ) );
		add_action( 'set_object_terms', array( __CLASS__, 'flush_for_post' ) );
		add_action( 'updated_post_meta', array( __CLASS__, 'flush_for_meta' ), 10, 2 );
		add_action( 'added_post_meta', array( __CLASS__, 'flush_for_meta' ), 10, 2 );
		add_action( 'deleted_post_meta', array( __CLASS__, 'flush_for_meta' ), 10, 2 );
	}

	public static function enabled() {
		return (bool) get_option( self::OPTION_ENABLED, false );
	}

	/**
	 * The directory, or a 404 error while the API is off or no startup data
	 * is found. The app shows its "coming soon" state on a 404.
	 *
	 * @return AllBioHub_App_API_Directory|WP_Error
	 */
	public static function directory() {
		if ( ! self::enabled() ) {
			return new WP_Error( 'allbiohub_app_api_disabled', __( 'The startup directory API is not enabled yet.', 'allbiohub-app-api' ), array( 'status' => 404 ) );
		}
		$startups = self::startups();
		if ( null === $startups ) {
			return new WP_Error( 'allbiohub_app_api_no_source', __( 'No startup data was found.', 'allbiohub-app-api' ), array( 'status' => 404 ) );
		}
		return new AllBioHub_App_API_Directory( $startups );
	}

	/**
	 * All live startups, mapped and cached.
	 *
	 * @return array[]|null Null when no data source is found.
	 */
	public static function startups( $use_cache = true ) {
		if ( $use_cache ) {
			$cached = get_transient( self::CACHE_KEY );
			if ( is_array( $cached ) ) {
				return $cached;
			}
		}
		$source = AllBioHub_App_API_Sources::detect();
		if ( ! $source ) {
			return null;
		}
		$built    = self::build( $source );
		$startups = $built['startups'];
		// An empty result isn't cached, so a fix on the website shows at once.
		if ( $startups ) {
			set_transient( self::CACHE_KEY, $startups, self::CACHE_TTL );
		}
		return $startups;
	}

	/**
	 * Reads and maps every record from a source.
	 *
	 * @return array { startups: array[], map: array, records: int }
	 */
	public static function build( AllBioHub_App_API_Source $source ) {
		$records = $source->records();
		$keys    = array();
		foreach ( $records as $record ) {
			$keys += array_flip( array_keys( $record['fields'] ) );
		}
		$map = apply_filters( 'allbiohub_app_api_field_map', AllBioHub_App_API_Mapper::guess_map( array_keys( $keys ) ), $source );

		$startups = array();
		$seen     = array();
		$paid     = $source instanceof AllBioHub_App_API_Post_Type_Source ? self::paid_featured_ids() : array();
		foreach ( $records as $record ) {
			$startup = AllBioHub_App_API_Mapper::to_startup( $record, $map, array( $source, 'image_url' ) );
			if ( ! $startup || isset( $seen[ $startup['slug'] ] ) ) {
				continue;
			}
			if ( isset( $paid[ (int) $startup['id'] ] ) ) {
				$startup['featured'] = true;
			}
			$seen[ $startup['slug'] ] = true;
			$startups[]               = apply_filters( 'allbiohub_app_api_startup', $startup, $record );
		}
		return array(
			'startups' => $startups,
			'map'      => $map,
			'records'  => count( $records ),
		);
	}

	/**
	 * Listing ids with a paid, unexpired featured placement in Directorist's
	 * orders table, when the site has one. Read-only.
	 *
	 * @return array<int, true>
	 */
	public static function paid_featured_ids() {
		global $wpdb;
		$table = $wpdb->prefix . 'directorist_orders';
		if ( $wpdb->get_var( $wpdb->prepare( 'SHOW TABLES LIKE %s', $wpdb->esc_like( $table ) ) ) !== $table ) {
			return array();
		}
		$columns = array_map( 'strtolower', (array) $wpdb->get_col( "SHOW COLUMNS FROM `{$table}`" ) );
		if ( array_diff( array( 'listing_id', 'is_featured_listing', 'status' ), $columns ) ) {
			return array();
		}
		$expiry = in_array( 'expires_at', $columns, true ) ? ' AND ( expires_at IS NULL OR expires_at > UTC_TIMESTAMP() )' : '';
		$ids    = $wpdb->get_col(
			"SELECT DISTINCT listing_id FROM `{$table}` WHERE is_featured_listing = 1 AND LOWER( status ) IN ( 'completed', 'complete', 'paid', 'active', 'approved' ){$expiry}"
		);
		return array_fill_keys( array_map( 'intval', (array) $ids ), true );
	}

	public static function flush() {
		delete_transient( self::CACHE_KEY );
	}

	public static function flush_for_post( $post_id ) {
		$type = get_post_type( $post_id );
		if ( $type && ! in_array( $type, array( 'post', 'page', 'attachment', 'revision', 'nav_menu_item' ), true ) ) {
			self::flush();
		}
	}

	public static function flush_for_meta( $meta_id, $post_id ) {
		self::flush_for_post( $post_id );
	}
}

AllBioHub_App_API::boot();

register_deactivation_hook( __FILE__, array( 'AllBioHub_App_API', 'flush' ) );
