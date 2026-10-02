<?php
/**
 * Unit tests for the mapping and directory logic. No WordPress needed:
 *
 *   php wordpress/allbiohub-app-api/tests/run.php
 *
 * @package AllBioHub_App_API
 */

define( 'ABSPATH', __DIR__ );

// Minimal stand-ins for the WordPress helpers the pure classes use.
function sanitize_title( $title ) {
	return trim( preg_replace( '/[^a-z0-9_-]+/', '-', strtolower( $title ) ), '-' );
}

require dirname( __DIR__ ) . '/includes/class-mapper.php';
require dirname( __DIR__ ) . '/includes/class-directory.php';

$failures = 0;
$count    = 0;
function check( $name, $expected, $actual ) {
	global $failures, $count;
	++$count;
	if ( $expected !== $actual ) {
		++$failures;
		echo "FAIL: $name\n  expected: " . var_export( $expected, true ) . "\n  actual:   " . var_export( $actual, true ) . "\n";
	}
}

use AllBioHub_App_API_Mapper as Mapper;

// --- Keys -----------------------------------------------------------------

check( 'prefix and case removed', 'industry', Mapper::normalize_key( '_Startup-Industry' ) );
check( 'company_stage kept', 'company_stage', Mapper::normalize_key( 'company_stage' ) );
check( 'bare prefix kept', 'startup', Mapper::normalize_key( 'startup_' ) );

$fields = Mapper::normalize_fields(
	array(
		'_industry'      => 'field_64ab12cd',
		'industry'       => 'Habitats',
		'_country'       => 'United States',
		'startup_city'   => '',
		'owner_email'    => 'owner@example.com',
		'stripe_customer' => 'cus_123',
	)
);
check( 'ACF field reference ignored, real value kept', 'Habitats', $fields['industry'] );
check( 'underscore key used when it is the only one', 'United States', $fields['country'] );
check( 'empty values dropped', false, isset( $fields['city'] ) );

// --- Mapping a record -----------------------------------------------------

$record = array(
	'id'         => 7,
	'slug'       => 'vast',
	'name'       => 'Vast &amp; Co',
	'link'       => 'https://allbiohub.com/startups/vast/',
	'created_at' => '2026-09-25 10:00:00',
	'updated_at' => '2026-09-26 08:30:00',
	'fields'     => Mapper::normalize_fields(
		array(
			'post_content'    => '<p>Vast is building <strong>Haven-1</strong>, a commercial space station. It launches soon.</p><script>x()</script>',
			'industry'        => array( 'Habitats', 'Space' ),
			'country'         => 'United States',
			'city'            => 'Long Beach',
			'founded_year'    => '2021',
			'company_stage'   => 'Series A',
			'funding_stage'   => 'Founder funding',
			'employees'       => '1,000+',
			'status'          => 'Active',
			'website'         => 'vastspace.com',
			'linkedin'        => 'https://linkedin.com/company/vast',
			'twitter'         => 'javascript:alert(1)',
			'founders'        => 'Jed McCaleb (Founder), Max Haot',
			'verified'        => 'yes',
			'claimed'         => '0',
			'owner_email'     => 'owner@example.com',
			'payment_status'  => 'paid',
		)
	),
);
$map     = Mapper::guess_map( array_keys( $record['fields'] ) );
$startup = Mapper::to_startup( $record, $map );
$public  = Mapper::public_view( $startup );

check( 'id', 7, $public['id'] );
check( 'name decoded', 'Vast & Co', $public['name'] );
check( 'description is plain text without scripts', 'Vast is building Haven-1, a commercial space station. It launches soon.', $public['description'] );
check( 'tagline falls back to first sentence', 'Vast is building Haven-1, a commercial space station.', $public['tagline'] );
check( 'several industries joined', 'Habitats, Space', $public['industry'] );
check( 'founded parsed to int', 2021, $public['founded'] );
check( 'company stage', 'Series A', $public['stage'] );
check( 'funding stage', 'Founder funding', $public['funding'] );
check( 'thousands separator not split', '1,000+', $public['employees'] );
check( 'status', 'Active', $public['status'] );
check( 'website gets https', 'https://vastspace.com', $public['website'] );
check( 'safe social link kept, unsafe dropped', array( 'linkedin' => 'https://linkedin.com/company/vast' ), (array) $public['social'] );
check(
	'founders parsed with roles',
	array(
		array( 'name' => 'Jed McCaleb', 'role' => 'Founder', 'url' => null ),
		array( 'name' => 'Max Haot', 'role' => null, 'url' => null ),
	),
	$public['founders']
);
check( 'verified true only when stated', true, $public['verified'] );
check( 'claimed false', false, $public['claimed'] );
check( 'featured false when missing', false, $public['featured'] );
check( 'dates in UTC ISO 8601', '2026-09-25T10:00:00Z', $public['created_at'] );
check( 'internal facets removed', false, array_key_exists( '_facets', $public ) );
$json = json_encode( $public );
check( 'private fields never output', false, strpos( $json, 'owner@example.com' ) !== false || strpos( $json, 'paid' ) !== false );
check(
	'only contract keys are output',
	array( 'id', 'slug', 'name', 'link', 'tagline', 'description', 'logo', 'industry', 'country', 'city', 'founded', 'stage', 'funding', 'business_model', 'employees', 'status', 'website', 'social', 'founders', 'products', 'verified', 'claimed', 'featured', 'created_at', 'updated_at', 'verified_at' ),
	array_keys( $public )
);

check( 'record without a name is skipped', null, Mapper::to_startup( array( 'id' => 1, 'slug' => 'x', 'name' => '', 'link' => 'https://a.b/' ), array() ) );
check( 'record without a valid link is skipped', null, Mapper::to_startup( array( 'id' => 1, 'slug' => 'x', 'name' => 'X', 'link' => 'ftp://a' ), array() ) );

$with_logo = Mapper::to_startup(
	array( 'id' => 2, 'slug' => 'l', 'name' => 'L', 'link' => 'https://a.b/l/', 'fields' => array( 'logo' => '55' ) ),
	array( 'logo' => 'logo' ),
	function ( $id ) {
		return "https://a.b/uploads/$id.png";
	}
);
check( 'logo attachment id resolved', 'https://a.b/uploads/55.png', $with_logo['logo'] );
check( 'social is a JSON object even when empty', '{}', json_encode( $with_logo['social'] ) );

check( 'JSON list values', array( 'SaaS', 'Fintech' ), Mapper::values( '["SaaS","Fintech"]' ) );
check( 'term objects', array( 'Media' ), Mapper::values( array( (object) array( 'name' => 'Media' ) ) ) );
check( 'duplicates removed case-insensitively', array( 'SaaS' ), Mapper::values( 'SaaS, saas' ) );

// --- Directory ------------------------------------------------------------

function make( $id, $name, $extra = array(), $created = '2026-01-01 00:00:00' ) {
	$raw = array_merge( array( 'tagline' => "$name tagline" ), $extra );
	return Mapper::to_startup(
		array(
			'id'         => $id,
			'slug'       => sanitize_title( $name ),
			'name'       => $name,
			'link'       => 'https://allbiohub.com/startups/' . sanitize_title( $name ) . '/',
			'created_at' => $created,
			'updated_at' => $created,
			'fields'     => Mapper::normalize_fields( $raw ),
		),
		Mapper::guess_map( array( 'tagline', 'industry', 'country', 'founded', 'verified', 'featured', 'stage' ) )
	);
}

$directory = new AllBioHub_App_API_Directory(
	array(
		make( 1, 'Paystack', array( 'industry' => 'Fintech', 'country' => 'Nigeria', 'founded' => '2015', 'verified' => '1' ), '2026-03-01 00:00:00' ),
		make( 2, 'Flutterwave', array( 'industry' => 'Fintech, Payments', 'country' => 'Nigeria', 'founded' => '2016' ), '2026-05-01 00:00:00' ),
		make( 3, 'Andela', array( 'industry' => 'Talent', 'country' => 'Kenya', 'founded' => '2014', 'featured' => '1' ), '2026-04-01 00:00:00' ),
		make( 4, 'Zeta', array( 'industry' => 'SaaS', 'country' => 'Ghana' ), '2026-02-01 00:00:00' ),
	)
);
$slugs = function ( $result ) {
	return array_map(
		function ( $s ) {
			return $s['slug'];
		},
		$result['items']
	);
};

check( 'newest first by default', array( 'flutterwave', 'andela', 'paystack', 'zeta' ), $slugs( $directory->query( array() ) ) );
check( 'by name', array( 'andela', 'flutterwave', 'paystack', 'zeta' ), $slugs( $directory->query( array( 'orderby' => 'name' ) ) ) );
check( 'verified first', 'paystack', $slugs( $directory->query( array( 'orderby' => 'verified' ) ) )[0] );
check( 'industry filter is case-insensitive and multi-valued', array( 'flutterwave', 'paystack' ), $slugs( $directory->query( array( 'industry' => 'fintech' ) ) ) );
check( 'filters combine', array( 'andela' ), $slugs( $directory->query( array( 'country' => 'Kenya', 'industry' => 'Talent' ) ) ) );
check( 'search all words', array( 'paystack' ), $slugs( $directory->query( array( 'search' => 'paystack tagline' ) ) ) );
check( 'founded range excludes unknown years', array( 'flutterwave', 'paystack' ), $slugs( $directory->query( array( 'founded_from' => 2015, 'founded_to' => 2016 ) ) ) );
check( 'featured flag', array( 'andela' ), $slugs( $directory->query( array( 'featured' => '1' ) ) ) );
check( 'not verified', 3, count( $directory->query( array( 'verified' => '0' ) )['items'] ) );

$page = $directory->query( array( 'per_page' => 3, 'page' => 2 ) );
check( 'second page', array( 'zeta' ), $slugs( $page ) );
check( 'total', 4, $page['total'] );
check( 'total pages', 2, $page['total_pages'] );
check( 'page past the end is empty', array(), $directory->query( array( 'page' => 9 ) )['items'] );
check( 'per_page capped at 50', 4, count( $directory->query( array( 'per_page' => 500 ) )['items'] ) );
check( 'results carry no internal keys', false, array_key_exists( '_facets', $directory->query( array() )['items'][0] ) );

check( 'find by slug', 'Andela', $directory->find( 'andela' )['name'] );
check( 'unknown slug', null, $directory->find( 'nope' ) );

$filters = $directory->filters();
check( 'industry options with counts, most common first', array( 'value' => 'Fintech', 'label' => 'Fintech', 'count' => 2 ), $filters['industries'][0] );
check( 'country options', array( 'Nigeria', 'Ghana', 'Kenya' ), array_column( $filters['countries'], 'value' ) );
check( 'all filter keys present', array( 'industries', 'countries', 'stages', 'funding', 'business_models', 'employees' ), array_keys( $filters ) );

echo $failures ? "\n$failures of $count checks failed.\n" : "All $count checks passed.\n";
exit( $failures ? 1 : 0 );
