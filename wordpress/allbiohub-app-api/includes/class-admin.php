<?php
/**
 * Tools → AllBioHub App API: shows what the plugin found and a preview of
 * what the app will receive, and switches the API on or off.
 *
 * @package AllBioHub_App_API
 */

defined( 'ABSPATH' ) || exit;

final class AllBioHub_App_API_Admin {

	const PAGE = 'allbiohub-app-api';

	public static function boot() {
		add_action( 'admin_menu', array( __CLASS__, 'menu' ) );
		add_action( 'admin_post_allbiohub_app_api_save', array( __CLASS__, 'save' ) );
		add_filter( 'plugin_action_links_' . plugin_basename( dirname( __DIR__ ) . '/allbiohub-app-api.php' ), array( __CLASS__, 'action_link' ) );
	}

	public static function menu() {
		add_management_page(
			__( 'AllBioHub App API', 'allbiohub-app-api' ),
			__( 'AllBioHub App API', 'allbiohub-app-api' ),
			'manage_options',
			self::PAGE,
			array( __CLASS__, 'render' )
		);
	}

	public static function action_link( $links ) {
		$url = admin_url( 'tools.php?page=' . self::PAGE );
		array_unshift( $links, '<a href="' . esc_url( $url ) . '">' . esc_html__( 'Settings', 'allbiohub-app-api' ) . '</a>' );
		return $links;
	}

	public static function save() {
		if ( ! current_user_can( 'manage_options' ) ) {
			wp_die( esc_html__( 'Sorry, you are not allowed to do that.', 'allbiohub-app-api' ), 403 );
		}
		check_admin_referer( 'allbiohub_app_api_save' );
		update_option( AllBioHub_App_API::OPTION_ENABLED, ! empty( $_POST['enabled'] ) ? 1 : 0, false );
		AllBioHub_App_API::flush();
		wp_safe_redirect( admin_url( 'tools.php?page=' . self::PAGE . '&updated=1' ) );
		exit;
	}

	public static function render() {
		if ( ! current_user_can( 'manage_options' ) ) {
			return;
		}
		$source  = AllBioHub_App_API_Sources::detect();
		$built   = $source ? AllBioHub_App_API::build( $source ) : null;
		$enabled = AllBioHub_App_API::enabled();
		$base    = rest_url( AllBioHub_App_API_Rest::NAMESPACE_V1 . '/startups' );
		?>
		<div class="wrap">
			<h1><?php esc_html_e( 'AllBioHub App API', 'allbiohub-app-api' ); ?></h1>
			<p><?php esc_html_e( 'Shares the startup directory with the AllBioHub app through read-only API routes. It never changes startups, pages or settings.', 'allbiohub-app-api' ); ?></p>

			<?php if ( isset( $_GET['updated'] ) ) : // phpcs:ignore WordPress.Security.NonceVerification.Recommended ?>
				<div class="notice notice-success is-dismissible"><p><?php esc_html_e( 'Saved.', 'allbiohub-app-api' ); ?></p></div>
			<?php endif; ?>

			<h2><?php esc_html_e( '1. Startup data found', 'allbiohub-app-api' ); ?></h2>
			<?php if ( ! $source ) : ?>
				<div class="notice notice-warning inline"><p>
					<?php esc_html_e( 'No startup post type or startup table was found. Make sure the startup directory plugin is active. If it stores data somewhere unusual, see the readme for the allbiohub_app_api_source filter.', 'allbiohub-app-api' ); ?>
				</p></div>
			<?php else : ?>
				<table class="widefat striped" style="max-width:720px">
					<tbody>
						<tr><th><?php esc_html_e( 'Source', 'allbiohub-app-api' ); ?></th><td><?php echo esc_html( $source->describe() ); ?></td></tr>
						<tr><th><?php esc_html_e( 'Live startups', 'allbiohub-app-api' ); ?></th><td><?php echo esc_html( count( $built['startups'] ) . ' / ' . $built['records'] ); ?></td></tr>
					</tbody>
				</table>

				<h2><?php esc_html_e( '2. Fields the app will show', 'allbiohub-app-api' ); ?></h2>
				<p><?php esc_html_e( 'Only these fields are ever sent. Anything else stored with a startup (emails, payments, notes) is never included.', 'allbiohub-app-api' ); ?></p>
				<table class="widefat striped" style="max-width:720px">
					<thead><tr><th><?php esc_html_e( 'App field', 'allbiohub-app-api' ); ?></th><th><?php esc_html_e( 'Read from', 'allbiohub-app-api' ); ?></th></tr></thead>
					<tbody>
						<?php foreach ( array_merge( array_keys( AllBioHub_App_API_Mapper::FIELDS ), array_map( function ( $n ) { return 'social_' . $n; }, array_keys( AllBioHub_App_API_Mapper::SOCIAL ) ) ) as $field ) : ?>
							<tr>
								<td><code><?php echo esc_html( $field ); ?></code></td>
								<td><?php echo isset( $built['map'][ $field ] ) ? '<code>' . esc_html( $built['map'][ $field ] ) . '</code>' : '<em>' . esc_html__( 'not found (hidden in the app)', 'allbiohub-app-api' ) . '</em>'; ?></td>
							</tr>
						<?php endforeach; ?>
					</tbody>
				</table>

				<?php if ( $built['startups'] ) : ?>
					<h2><?php esc_html_e( '3. Preview', 'allbiohub-app-api' ); ?></h2>
					<p><?php esc_html_e( 'The first startup exactly as the app will receive it:', 'allbiohub-app-api' ); ?></p>
					<pre style="max-width:720px;max-height:420px;overflow:auto;background:#fff;border:1px solid #ccd0d4;padding:12px"><?php echo esc_html( wp_json_encode( AllBioHub_App_API_Mapper::public_view( $built['startups'][0] ), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE ) ); ?></pre>
				<?php endif; ?>
			<?php endif; ?>

			<h2><?php esc_html_e( '4. Turn on', 'allbiohub-app-api' ); ?></h2>
			<form method="post" action="<?php echo esc_url( admin_url( 'admin-post.php' ) ); ?>">
				<input type="hidden" name="action" value="allbiohub_app_api_save">
				<?php wp_nonce_field( 'allbiohub_app_api_save' ); ?>
				<label>
					<input type="checkbox" name="enabled" value="1" <?php checked( $enabled ); ?> <?php disabled( ! $source && ! $enabled ); ?>>
					<?php esc_html_e( 'Share the startup directory with the app', 'allbiohub-app-api' ); ?>
				</label>
				<p class="description">
					<?php if ( $enabled ) : ?>
						<?php
						/* translators: %s: API URL. */
						printf( esc_html__( 'On. The app reads %s.', 'allbiohub-app-api' ), '<a href="' . esc_url( $base ) . '" target="_blank" rel="noopener"><code>' . esc_html( $base ) . '</code></a>' );
						?>
					<?php else : ?>
						<?php esc_html_e( 'Off. The app shows "coming soon" for startups until this is on.', 'allbiohub-app-api' ); ?>
					<?php endif; ?>
				</p>
				<?php submit_button( __( 'Save', 'allbiohub-app-api' ) ); ?>
			</form>
		</div>
		<?php
	}
}
