<?php
/**
 * Search, filters, sorting and pagination over the mapped startups.
 *
 * The directory is small (hundreds of startups), so the whole list is built
 * once, cached, and queried in memory. This keeps every data source behaving
 * the same way and needs no database changes.
 *
 * @package AllBioHub_App_API
 */

defined( 'ABSPATH' ) || exit;

final class AllBioHub_App_API_Directory {

	const MAX_PER_PAGE = 50;

	/** Request parameter => facet. */
	const FILTERS = array(
		'industry'       => 'industry',
		'country'        => 'country',
		'city'           => 'city',
		'stage'          => 'stage',
		'funding'        => 'funding',
		'business_model' => 'business_model',
		'employees'      => 'employees',
	);

	/** Facet => key in the /filters response. */
	const FILTER_KEYS = array(
		'industry'       => 'industries',
		'country'        => 'countries',
		'stage'          => 'stages',
		'funding'        => 'funding',
		'business_model' => 'business_models',
		'employees'      => 'employees',
	);

	/** @var array[] */
	private $startups;

	/**
	 * @param array[] $startups From AllBioHub_App_API_Mapper::to_startup().
	 */
	public function __construct( array $startups ) {
		$this->startups = array_values( $startups );
	}

	/**
	 * @param array $params Request parameters (see API.md).
	 * @return array { items: array[], total: int, total_pages: int }
	 */
	public function query( array $params ) {
		$per_page = isset( $params['per_page'] ) ? (int) $params['per_page'] : 10;
		$per_page = max( 1, min( self::MAX_PER_PAGE, $per_page ) );
		$page     = isset( $params['page'] ) ? max( 1, (int) $params['page'] ) : 1;

		$items = array_values( array_filter( $this->startups, $this->matcher( $params ) ) );
		usort( $items, $this->sorter( isset( $params['orderby'] ) ? (string) $params['orderby'] : 'newest' ) );

		$total = count( $items );
		$items = array_slice( $items, ( $page - 1 ) * $per_page, $per_page );
		return array(
			'items'       => array_map( array( 'AllBioHub_App_API_Mapper', 'public_view' ), $items ),
			'total'       => $total,
			'total_pages' => (int) ceil( $total / $per_page ),
		);
	}

	/** @return array|null */
	public function find( $slug ) {
		foreach ( $this->startups as $startup ) {
			if ( $startup['slug'] === $slug ) {
				return AllBioHub_App_API_Mapper::public_view( $startup );
			}
		}
		return null;
	}

	/** Values that exist in the directory, most common first. */
	public function filters() {
		$out = array();
		foreach ( self::FILTER_KEYS as $facet => $key ) {
			$counts = array();
			foreach ( $this->startups as $startup ) {
				foreach ( $startup['_facets'][ $facet ] as $label ) {
					$id = strtolower( $label );
					if ( ! isset( $counts[ $id ] ) ) {
						$counts[ $id ] = array(
							'value' => $label,
							'label' => $label,
							'count' => 0,
						);
					}
					++$counts[ $id ]['count'];
				}
			}
			$options = array_values( $counts );
			usort(
				$options,
				function ( $a, $b ) {
					return array( $b['count'], $a['label'] ) <=> array( $a['count'], $b['label'] );
				}
			);
			$out[ $key ] = $options;
		}
		return $out;
	}

	private function matcher( array $params ) {
		$search = isset( $params['search'] ) ? self::fold( $params['search'] ) : '';
		$wanted = array();
		foreach ( self::FILTERS as $param => $facet ) {
			if ( isset( $params[ $param ] ) && '' !== trim( (string) $params[ $param ] ) ) {
				$wanted[ $facet ] = self::fold( $params[ $param ] );
			}
		}
		$from  = isset( $params['founded_from'] ) && '' !== $params['founded_from'] ? (int) $params['founded_from'] : null;
		$to    = isset( $params['founded_to'] ) && '' !== $params['founded_to'] ? (int) $params['founded_to'] : null;
		$flags = array();
		foreach ( array( 'verified', 'claimed', 'featured' ) as $flag ) {
			if ( isset( $params[ $flag ] ) && '' !== (string) $params[ $flag ] ) {
				$flags[ $flag ] = AllBioHub_App_API_Mapper::boolean( $params[ $flag ] );
			}
		}

		return function ( array $s ) use ( $search, $wanted, $from, $to, $flags ) {
			if ( '' !== $search ) {
				$haystack = self::fold( $s['name'] . ' ' . $s['tagline'] . ' ' . $s['description'] . ' ' . $s['industry'] );
				foreach ( preg_split( '/\s+/', $search ) as $word ) {
					if ( false === strpos( $haystack, $word ) ) {
						return false;
					}
				}
			}
			foreach ( $wanted as $facet => $value ) {
				if ( ! in_array( $value, array_map( array( __CLASS__, 'fold' ), $s['_facets'][ $facet ] ), true ) ) {
					return false;
				}
			}
			if ( null !== $from && ( null === $s['founded'] || $s['founded'] < $from ) ) {
				return false;
			}
			if ( null !== $to && ( null === $s['founded'] || $s['founded'] > $to ) ) {
				return false;
			}
			foreach ( $flags as $flag => $value ) {
				if ( $s[ $flag ] !== $value ) {
					return false;
				}
			}
			return true;
		};
	}

	private function sorter( $orderby ) {
		$by_name = function ( $a, $b ) {
			return strnatcasecmp( $a['name'], $b['name'] );
		};
		$by_date = function ( $key ) use ( $by_name ) {
			return function ( $a, $b ) use ( $key, $by_name ) {
				return ( (string) $b[ $key ] <=> (string) $a[ $key ] ) ?: $by_name( $a, $b );
			};
		};
		switch ( $orderby ) {
			case 'name':
				return $by_name;
			case 'updated':
				return $by_date( 'updated_at' );
			case 'verified':
				$newest = $by_date( 'created_at' );
				return function ( $a, $b ) use ( $newest ) {
					return ( (int) $b['verified'] <=> (int) $a['verified'] ) ?: $newest( $a, $b );
				};
			default:
				return $by_date( 'created_at' );
		}
	}

	/** Lowercase, accents removed, trimmed: for case-insensitive matching. */
	public static function fold( $text ) {
		$text = trim( (string) $text );
		if ( function_exists( 'remove_accents' ) ) {
			$text = remove_accents( $text );
		}
		return function_exists( 'mb_strtolower' ) ? mb_strtolower( $text, 'UTF-8' ) : strtolower( $text );
	}
}
