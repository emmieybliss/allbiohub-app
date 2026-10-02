<?php
/**
 * Removes the plugin's own option and cache. Startup data is never touched.
 *
 * @package AllBioHub_App_API
 */

defined( 'WP_UNINSTALL_PLUGIN' ) || exit;

delete_option( 'allbiohub_app_api_enabled' );
delete_transient( 'allbiohub_app_api_startups' );
