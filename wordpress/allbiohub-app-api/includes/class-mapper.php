<?php
/**
 * Turns raw startup records (post fields, meta, terms or table columns) into
 * the public startup object the app expects.
 *
 * Only the fields listed in FIELDS are ever output, so anything else stored
 * with a startup (owner emails, payment details, internal notes) can't leak
 * through the API, whatever the source contains.
 *
 * Pure PHP apart from a few WordPress helpers that have fallbacks, so it can
 * be unit tested without WordPress.
 *
 * @package AllBioHub_App_API
 */

defined( 'ABSPATH' ) || exit;

final class AllBioHub_App_API_Mapper {

	/**
	 * Output field => source keys to look for, best first. Keys are compared
	 * after normalisation (lowercase, underscores, common prefixes removed).
	 */
	const FIELDS = array(
		'tagline'        => array( 'tagline', 'short_description', 'one_liner', 'subtitle', 'summary', 'excerpt', 'post_excerpt' ),
		'description'    => array( 'description', 'long_description', 'about', 'overview', 'company_description', 'content', 'post_content' ),
		'logo'           => array( 'logo', 'logo_url', 'company_logo', 'logo_id', 'image', 'thumbnail' ),
		'industry'       => array( 'industry', 'industries', 'sector', 'sectors' ),
		'country'        => array( 'country', 'hq_country', 'headquarters_country', 'location_country', 'countries' ),
		'city'           => array( 'city', 'hq_city', 'headquarters_city', 'location_city', 'cities' ),
		'founded'        => array( 'founded', 'founded_year', 'year_founded', 'founding_year', 'established', 'founded_in' ),
		'stage'          => array( 'company_stage', 'stage', 'startup_stage', 'stages' ),
		'funding'        => array( 'funding_stage', 'funding', 'funding_type', 'funding_status', 'funding_round' ),
		'business_model' => array( 'business_model', 'business_models', 'revenue_model' ),
		'employees'      => array( 'employees', 'employee_count', 'employee_range', 'team_size', 'company_size', 'number_of_employees' ),
		'status'         => array( 'company_status', 'operating_status', 'operational_status', 'status' ),
		'website'        => array( 'website', 'website_url', 'company_website', 'homepage', 'url' ),
		'founders'       => array( 'founders', 'founder', 'founder_names', 'founder_name', 'founding_team' ),
		'products'       => array( 'products', 'product', 'product_names' ),
		'verified'       => array( 'verified', 'is_verified' ),
		'claimed'        => array( 'claimed', 'is_claimed' ),
		'featured'       => array( 'featured', 'is_featured' ),
		'verified_at'    => array( 'verified_at', 'verified_date', 'verification_date' ),
	);

	/** Social network => source keys. */
	const SOCIAL = array(
		'linkedin'   => array( 'linkedin', 'linkedin_url' ),
		'x'          => array( 'x', 'x_url', 'twitter', 'twitter_url' ),
		'facebook'   => array( 'facebook', 'facebook_url' ),
		'instagram'  => array( 'instagram', 'instagram_url' ),
		'youtube'    => array( 'youtube', 'youtube_url' ),
		'tiktok'     => array( 'tiktok', 'tiktok_url' ),
		'github'     => array( 'github', 'github_url' ),
		'crunchbase' => array( 'crunchbase', 'crunchbase_url' ),
	);

	/** Fields that can hold several values and are offered as filters. */
	const FACETS = array( 'industry', 'country', 'city', 'stage', 'funding', 'business_model', 'employees' );

	/** Prefixes plugins commonly put in front of their field names. */
	const PREFIXES = array( 'startup_', 'startups_', 'abs_', 'ab_', 'allbiohub_', 'sd_', 'wpcf_' );

	/**
	 * Normalises a source key: "_Startup-Industry" => "industry".
	 */
	public static function normalize_key( $key ) {
		$key = strtolower( trim( (string) $key ) );
		$key = preg_replace( '/[^a-z0-9]+/', '_', $key );
		$key = trim( $key, '_' );
		foreach ( self::PREFIXES as $prefix ) {
			if ( 0 === strpos( $key, $prefix ) && strlen( $key ) > strlen( $prefix ) ) {
				$key = substr( $key, strlen( $prefix ) );
				break;
			}
		}
		return $key;
	}

	/**
	 * Normalises raw fields: keys normalised, empty values dropped, and the
	 * first value kept when two source keys normalise to the same name.
	 *
	 * @param array $raw Source key => value.
	 * @return array
	 */
	public static function normalize_fields( array $raw ) {
		// Keys without a leading underscore win over "_key" duplicates, which
		// are often field references (ACF stores "_industry" => "field_…").
		uksort(
			$raw,
			function ( $a, $b ) {
				return ( '_' === substr( (string) $a, 0, 1 ) ) <=> ( '_' === substr( (string) $b, 0, 1 ) );
			}
		);
		$out = array();
		foreach ( $raw as $key => $value ) {
			$norm = self::normalize_key( $key );
			if ( '' === $norm || array_key_exists( $norm, $out ) || self::is_empty( $value ) ) {
				continue;
			}
			if ( is_string( $value ) && preg_match( '/^field_[0-9a-f]{6,}$/', $value ) ) {
				continue;
			}
			$out[ $norm ] = $value;
		}
		return $out;
	}

	/**
	 * Which source key feeds each output field, given the keys seen across
	 * all records. Unmatched fields are left out.
	 *
	 * @param string[] $available Normalised keys.
	 * @return array Output field => source key.
	 */
	public static function guess_map( array $available ) {
		$available = array_flip( $available );
		$map       = array();
		foreach ( array_merge( self::FIELDS, self::social_fields() ) as $field => $candidates ) {
			foreach ( $candidates as $candidate ) {
				if ( isset( $available[ $candidate ] ) ) {
					$map[ $field ] = $candidate;
					break;
				}
			}
		}
		return $map;
	}

	/**
	 * Builds the public startup object.
	 *
	 * @param array         $record        id, slug, name, link, created_at,
	 *                                     updated_at, logo (optional) and
	 *                                     fields (normalised key => value).
	 * @param array         $map           From guess_map().
	 * @param callable|null $resolve_image Turns an attachment id into a URL.
	 * @return array|null Null when the record lacks an id, slug or name.
	 */
	public static function to_startup( array $record, array $map, $resolve_image = null ) {
		$id   = isset( $record['id'] ) ? (int) $record['id'] : 0;
		$slug = isset( $record['slug'] ) ? sanitize_title( (string) $record['slug'] ) : '';
		$name = isset( $record['name'] ) ? self::text( $record['name'] ) : '';
		if ( $id <= 0 || '' === $slug || '' === $name ) {
			return null;
		}
		$fields = isset( $record['fields'] ) ? $record['fields'] : array();
		$get    = function ( $field ) use ( $map, $fields ) {
			return isset( $map[ $field ], $fields[ $map[ $field ] ] ) ? $fields[ $map[ $field ] ] : null;
		};

		$logo = isset( $record['logo'] ) && $record['logo'] ? $record['logo'] : $get( 'logo' );
		if ( is_numeric( $logo ) && $resolve_image ) {
			$logo = call_user_func( $resolve_image, (int) $logo );
		} elseif ( is_array( $logo ) ) {
			$logo = isset( $logo['url'] ) ? $logo['url'] : ( isset( $logo['sizes']['large'] ) ? $logo['sizes']['large'] : null );
		}

		$facets = array();
		foreach ( self::FACETS as $facet ) {
			$facets[ $facet ] = self::values( $get( $facet ) );
		}

		$description = self::text( $get( 'description' ) );
		$tagline     = self::text( $get( 'tagline' ) );
		if ( '' === $tagline && '' !== $description ) {
			$tagline = self::first_sentence( $description );
		}

		$social = array();
		foreach ( array_keys( self::SOCIAL ) as $network ) {
			$url = self::url( $get( 'social_' . $network ) );
			if ( $url ) {
				$social[ $network ] = $url;
			}
		}

		$startup = array(
			'id'             => $id,
			'slug'           => $slug,
			'name'           => $name,
			'link'           => self::url( isset( $record['link'] ) ? $record['link'] : '' ),
			'tagline'        => self::nullable( $tagline ),
			'description'    => self::nullable( $description ),
			'logo'           => self::url( $logo ),
			'industry'       => self::nullable( implode( ', ', $facets['industry'] ) ),
			'country'        => self::nullable( implode( ', ', $facets['country'] ) ),
			'city'           => self::nullable( implode( ', ', $facets['city'] ) ),
			'founded'        => self::year( $get( 'founded' ) ),
			'stage'          => self::nullable( implode( ', ', $facets['stage'] ) ),
			'funding'        => self::nullable( implode( ', ', $facets['funding'] ) ),
			'business_model' => self::nullable( implode( ', ', $facets['business_model'] ) ),
			'employees'      => self::nullable( implode( ', ', $facets['employees'] ) ),
			'status'         => self::nullable( self::text( self::first( $get( 'status' ) ) ) ),
			'website'        => self::url( $get( 'website' ), true ),
			'social'         => (object) $social,
			'founders'       => self::founders( $get( 'founders' ) ),
			'products'       => self::values( $get( 'products' ) ),
			'verified'       => self::boolean( $get( 'verified' ) ),
			'claimed'        => self::boolean( $get( 'claimed' ) ),
			'featured'       => self::boolean( $get( 'featured' ) ),
			'created_at'     => self::date( isset( $record['created_at'] ) ? $record['created_at'] : null ),
			'updated_at'     => self::date( isset( $record['updated_at'] ) ? $record['updated_at'] : null ),
			'verified_at'    => self::date( $get( 'verified_at' ) ),
		);
		if ( null === $startup['link'] ) {
			return null;
		}
		// Kept for filtering only; removed before output.
		$startup['_facets'] = $facets;
		return $startup;
	}

	/** Removes internal keys before a startup is sent. */
	public static function public_view( array $startup ) {
		unset( $startup['_facets'] );
		return $startup;
	}

	private static function social_fields() {
		$out = array();
		foreach ( self::SOCIAL as $network => $keys ) {
			$out[ 'social_' . $network ] = $keys;
		}
		return $out;
	}

	private static function is_empty( $value ) {
		return null === $value || '' === $value || array() === $value || ( is_string( $value ) && '' === trim( $value ) );
	}

	/** Plain text: tags stripped, entities decoded, whitespace collapsed. */
	public static function text( $value ) {
		if ( is_array( $value ) || is_object( $value ) ) {
			return '';
		}
		$value = preg_replace( '#<(script|style)[^>]*>.*?</\1>#is', '', (string) $value );
		$value = preg_replace( '#</(p|div|h[1-6]|li)>|<br\s*/?>#i', "\n", $value );
		$value = html_entity_decode( strip_tags( $value ), ENT_QUOTES | ENT_HTML5, 'UTF-8' );
		$value = preg_replace( "/[ \t\x{00A0}]+/u", ' ', $value );
		$value = preg_replace( "/\s*\n\s*(\n\s*)*/", "\n\n", $value );
		return trim( $value );
	}

	private static function nullable( $value ) {
		return '' === $value ? null : $value;
	}

	private static function first( $value ) {
		$values = self::values( $value );
		return $values ? $values[0] : '';
	}

	private static function first_sentence( $text ) {
		$line = strtok( $text, "\n" );
		if ( preg_match( '/^(.{20,160}?[.!?])(\s|$)/u', $line, $m ) ) {
			return $m[1];
		}
		return function_exists( 'mb_strlen' ) && mb_strlen( $line ) > 160 ? rtrim( mb_substr( $line, 0, 157 ) ) . '…' : $line;
	}

	/**
	 * A list of distinct text values from a string ("A, B"), an array of
	 * strings, an array of terms or a JSON array.
	 *
	 * @return string[]
	 */
	public static function values( $value ) {
		if ( is_string( $value ) ) {
			$trimmed = trim( $value );
			if ( '' !== $trimmed && ( '[' === $trimmed[0] ) ) {
				$decoded = json_decode( $trimmed, true );
				if ( is_array( $decoded ) ) {
					$value = $decoded;
				}
			}
		}
		if ( is_object( $value ) ) {
			$value = array( $value );
		}
		$items = is_array( $value ) ? $value : preg_split( '/\s*(?:[;|]|,(?!\d{3}\b))\s*/', (string) $value );
		$out   = array();
		foreach ( $items as $item ) {
			if ( is_object( $item ) ) {
				$item = isset( $item->name ) ? $item->name : '';
			} elseif ( is_array( $item ) ) {
				$item = isset( $item['name'] ) ? $item['name'] : ( isset( $item['label'] ) ? $item['label'] : '' );
			}
			$text = self::text( $item );
			if ( '' !== $text && ! in_array( strtolower( $text ), array_map( 'strtolower', $out ), true ) ) {
				$out[] = $text;
			}
		}
		return $out;
	}

	private static function year( $value ) {
		if ( is_numeric( $value ) && (int) $value >= 1800 && (int) $value <= 2100 ) {
			return (int) $value;
		}
		if ( is_string( $value ) && preg_match( '/\b(1[89]\d\d|20\d\d)\b/', $value, $m ) ) {
			return (int) $m[1];
		}
		return null;
	}

	/** True only for an explicit yes; anything else (including missing) is false. */
	public static function boolean( $value ) {
		if ( is_bool( $value ) ) {
			return $value;
		}
		if ( is_array( $value ) ) {
			$value = reset( $value );
		}
		return in_array( strtolower( trim( (string) $value ) ), array( '1', 'yes', 'true', 'on', 'verified', 'claimed', 'featured' ), true );
	}

	/**
	 * An absolute http(s) URL, or null. With $add_scheme, "example.com"
	 * becomes "https://example.com".
	 */
	public static function url( $value, $add_scheme = false ) {
		if ( is_array( $value ) ) {
			$value = isset( $value['url'] ) ? $value['url'] : reset( $value );
		}
		$value = trim( (string) $value );
		if ( '' === $value ) {
			return null;
		}
		if ( $add_scheme && ! preg_match( '#^[a-z][a-z0-9+.-]*:#i', $value ) && preg_match( '#^[a-z0-9.-]+\.[a-z]{2,}(/|$)#i', $value ) ) {
			$value = 'https://' . $value;
		}
		$scheme = strtolower( (string) parse_url( $value, PHP_URL_SCHEME ) );
		if ( ! in_array( $scheme, array( 'http', 'https' ), true ) || ! filter_var( $value, FILTER_VALIDATE_URL ) ) {
			return null;
		}
		return $value;
	}

	/** ISO 8601 in UTC, or null. Expects GMT for "Y-m-d H:i:s" strings. */
	private static function date( $value ) {
		if ( null === $value || '' === $value || '0000-00-00 00:00:00' === $value ) {
			return null;
		}
		if ( is_numeric( $value ) ) {
			$ts = (int) $value;
		} else {
			$ts = strtotime( preg_match( '/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$/', (string) $value ) ? $value . ' UTC' : (string) $value );
		}
		return $ts ? gmdate( 'Y-m-d\TH:i:s\Z', $ts ) : null;
	}

	/** Founders from names, "Name (Role)", or arrays with name/role/url. */
	private static function founders( $value ) {
		if ( is_string( $value ) ) {
			$decoded = json_decode( $value, true );
			if ( is_array( $decoded ) ) {
				$value = $decoded;
			}
		}
		$items = is_array( $value ) ? $value : preg_split( '/\s*(?:[,;|\n]|\band\b|&)\s*/i', (string) $value );
		$out   = array();
		foreach ( $items as $item ) {
			$role = null;
			$url  = null;
			if ( is_array( $item ) ) {
				$name = isset( $item['name'] ) ? $item['name'] : ( isset( $item['founder_name'] ) ? $item['founder_name'] : '' );
				$role = isset( $item['role'] ) ? $item['role'] : ( isset( $item['title'] ) ? $item['title'] : null );
				$url  = isset( $item['url'] ) ? $item['url'] : ( isset( $item['linkedin'] ) ? $item['linkedin'] : null );
			} else {
				$name = (string) $item;
				if ( preg_match( '/^(.+?)\s*\(([^)]+)\)$/', trim( $name ), $m ) ) {
					$name = $m[1];
					$role = $m[2];
				}
			}
			$name = self::text( $name );
			if ( '' === $name ) {
				continue;
			}
			$role  = self::text( $role );
			$out[] = array(
				'name' => $name,
				'role' => '' === $role ? null : $role,
				'url'  => self::url( $url ),
			);
		}
		return $out;
	}
}
