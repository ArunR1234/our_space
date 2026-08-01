class ServerConfig {
  /// Set to true to point the app to the deployed Oracle Cloud production server.
  /// Set to false to run the app against a local backend server (development mode).
  static const bool useProduction = true;

  /// Set to true once you have configured SSL/HTTPS (using Let's Encrypt / Certbot)
  /// on your production server. For now, we use HTTP/WS (unsecure).
  static const bool productionUseHttps = false;

  /// Your production server IP or domain name.
  static const String productionHost = '129.159.229.68';

  /// Your current local machine LAN IP fallback (for testing locally with real devices).
  static const String localHostFallback = '10.119.115.59';
}
