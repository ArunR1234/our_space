<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Security Alert: New Device Login</title>
  <style>
    body { margin: 0; padding: 0; background: #FFF5F7; font-family: 'Georgia', serif; }
    .wrapper { max-width: 520px; margin: 40px auto; background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 4px 24px rgba(181,0,63,0.08); }
    .header { background: linear-gradient(135deg, #B5003F 0%, #8A003D 100%); padding: 36px 32px; text-align: center; }
    .header h1 { margin: 0; color: #ffffff; font-size: 26px; letter-spacing: 1px; }
    .header p  { margin: 6px 0 0; color: rgba(255,255,255,0.8); font-size: 13px; letter-spacing: 0.5px; }
    .body { padding: 36px 32px; text-align: center; }
    .body p.greeting { font-size: 16px; color: #2C1820; margin-bottom: 8px; font-weight: bold; }
    .body p.sub { font-size: 14px; color: #8E717D; margin-bottom: 28px; line-height: 1.5; }
    .device-info-box { display: inline-block; background: #FFF0F3; border: 2px dashed #B5003F; border-radius: 16px; padding: 22px 30px; margin-bottom: 28px; text-align: left; }
    .device-info-box p { margin: 6px 0; font-size: 14px; color: #2C1820; }
    .device-info-box strong { color: #B5003F; }
    .note { font-size: 13px; color: #8E717D; margin-bottom: 8px; line-height: 1.5; }
    .warning { font-size: 12px; color: #c0392b; margin-top: 16px; font-weight: bold; }
    .footer { background: #FFF5F7; padding: 20px 32px; text-align: center; }
    .footer p { font-size: 12px; color: #B5003F; margin: 0; }
    .heart { font-size: 20px; }

    @media only screen and (max-width: 480px) {
      .wrapper { margin: 20px 12px !important; border-radius: 16px !important; }
      .header { padding: 28px 20px !important; }
      .header h1 { font-size: 22px !important; }
      .body { padding: 28px 20px !important; }
      .device-info-box { padding: 16px 20px !important; margin-bottom: 20px !important; border-radius: 12px !important; }
      .footer { padding: 16px 20px !important; }
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <div class="heart">🛡️</div>
      <h1>Security Alert</h1>
      <p>New Device Login Detected</p>
    </div>
    <div class="body">
      <p class="greeting">Hello, My Love 💌</p>
      <p class="sub">A new device recently logged into your <strong>Our Space</strong> account. Please review the details below:</p>
      <div class="device-info-box">
        <p>📱 <strong>Device:</strong> {{ $deviceName }}</p>
        <p>🌐 <strong>IP Address:</strong> {{ $ipAddress }}</p>
        <p>🕒 <strong>Time:</strong> {{ $loginTime }}</p>
      </div>
      <p class="note">If this was you, no action is required.</p>
      <p class="warning">⚠️ If you don't recognize this device, please immediately go to Settings > Logged-in Devices in the app, log out the session, and change your password.</p>
    </div>
    <div class="footer">
      <p>Sent with love & security by Our Space ❤️</p>
    </div>
  </div>
</body>
</html>
