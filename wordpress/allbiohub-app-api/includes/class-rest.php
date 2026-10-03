<?php
/**
 * Public, read-only REST routes for the AllBioHub app:
 *
 *   GET /wp-json/allbiohub/v1/startups
 *   GET /wp-json/allbiohub/v1/startups/filters
 *   GET /wp-json/allbiohub/v1/startups/{slug}
 *
 * The contract is documented in API.md in the app repository.
 *
 * @package AllBioHub_App_API
 */

defined( 'ABSPATH' ) || exit;

final class AllBioHub_App_API_Rest {

	const NAMESPACE_V1 = 'allbiohub/v1';

	public static function register() {
		$readable = array(
			'methods'             => WP_REST_Server::READABLE,
			'permission_callback' => '__return_true',
		);
		// /filters is registered before /{slug} so it isn't read as a slug.
		register_rest_route(
			self::NAMESPACE_V1,
			'/startups/filters',
			$readable + array( 'callback' => array( __CLASS__, 'filters' ) )
		);
		register_rest_route(
			self::NAMESPACE_V1,
			'/status',
			$readable + array( 'callback' => array( __CLASS__, 'status' ) )
		);
		register_rest_route(
			self::NAMESPACE_V1,
			'/startups/(?P<slug>[a-z0-9][a-z0-9_-]*)',
			$readable + array( 'callback' => array( __CLASS__, 'single' ) )
		);
		register_rest_route(
			self::NAMESPACE_V1,
			'/startups',
			$readable + array(
				'callback' => array( __CLASS__, 'collection' ),
				'args'     => self::collection_args(),
			)
		);
	}

	public static function collection( WP_REST_Request $request ) {
		$directory = AllBioHub_App_API::directory();
		if ( is_wp_error( $directory ) ) {
			return $directory;
		}
		$result   = $directory->query( $request->get_params() );
		$response = rest_ensure_response( $result['items'] );
		$response->header( 'X-WP-Total', (string) $result['total'] );
		$response->header( 'X-WP-TotalPages', (string) $result['total_pages'] );
		return self::cacheable( $response );
	}

	/**
	 * What the API sees, for troubleshooting from outside wp-admin: the
	 * source in use and how many startups it maps. Counts only, no records.
	 */
	public static function status() {
		$source  = AllBioHub_App_API::enabled() ? AllBioHub_App_API_Sources::detect() : null;
		$built   = $source ? AllBioHub_App_API::build( $source ) : null;
		$flagged = function ( $flag ) use ( $built ) {
			return $built ? count( array_filter( wp_list_pluck( $built['startups'], $flag ) ) ) : 0;
		};
		$response = rest_ensure_response(
			array(
				'version'  => ALLBIOHUB_APP_API_VERSION,
				'enabled'  => AllBioHub_App_API::enabled(),
				'source'   => $source ? $source->describe() : null,
				'records'  => $built ? $built['records'] : 0,
				'startups' => $built ? count( $built['startups'] ) : 0,
				'featured' => $flagged( 'featured' ),
				'verified' => $flagged( 'verified' ),
				'fields'   => $built ? array_keys( array_filter( $built['map'] ) ) : array(),
			)
		);
		$response->header( 'Cache-Control', 'no-store' );
		return $response;
	}

	public static function single( WP_REST_Request $request ) {
		$directory = AllBioHub_App_API::directory();
		if ( is_wp_error( $directory ) ) {
			return $directory;
		}
		$startup = $directory->find( $request['slug'] );
		if ( ! $startup ) {
			return new WP_Error( 'allbiohub_startup_not_found', __( 'Startup not found.', 'allbiohub-app-api' ), array( 'status' => 404 ) );
		}
		return self::cacheable( rest_ensure_response( $startup ) );
	}

	public static function filters() {
		$directory = AllBioHub_App_API::directory();
		if ( is_wp_error( $directory ) ) {
			return $directory;
		}
		return self::cacheable( rest_ensure_response( $directory->filters() ) );
	}

	/** Lets LiteSpeed and CDNs cache responses for five minutes. */
	private static function cacheable( WP_REST_Response $response ) {
		$response->header( 'Cache-Control', 'public, max-age=300' );
		return $response;
	}

	private static function collection_args() {
		$text = array(
			'type'              => 'string',
			'sanitize_callback' => 'sanitize_text_field',
		);
		$int  = array(
			'type'              => 'integer',
			'sanitize_callback' => 'absint',
		);
		$flag = array(
			'type' => 'string',
			'enum' => array( '0', '1', 'true', 'false' ),
		);
		return array(
			'page'           => $int + array( 'default' => 1 ),
			'per_page'       => $int + array(
				'default' => 10,
				'minimum' => 1,
				'maximum' => AllBioHub_App_API_Directory::MAX_PER_PAGE,
			),
			'search'         => $text,
			'industry'       => $text,
			'country'        => $text,
			'city'           => $text,
			'stage'          => $text,
			'funding'        => $text,
			'business_model' => $text,
			'employees'      => $text,
			'founded_from'   => $int,
			'founded_to'     => $int,
			'verified'       => $flag,
			'claimed'        => $flag,
			'featured'       => $flag,
			'orderby'        => array(
				'type'    => 'string',
				'enum'    => array( 'newest', 'updated', 'founded', 'oldest', 'name', 'featured', 'verified' ),
				'default' => 'newest',
			),
		);
	}
}
