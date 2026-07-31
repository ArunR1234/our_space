<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Email Verification – Our Space</title>
  <style>
    body { margin: 0; padding: 0; background: #FFF5F7; font-family: 'Georgia', serif; }
    .wrapper { max-width: 520px; margin: 40px auto; background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 4px 24px rgba(181,0,63,0.08); }
    .header { background: linear-gradient(135deg, #B5003F 0%, #8A003D 100%); padding: 36px 32px; text-align: center; }
    .header h1 { margin: 0; color: #ffffff; font-size: 26px; letter-spacing: 1px; }
    .header p  { margin: 6px 0 0; color: rgba(255,255,255,0.8); font-size: 13px; letter-spacing: 0.5px; }
    .body { padding: 36px 32px; text-align: center; }
    .body p.greeting { font-size: 16px; color: #2C1820; margin-bottom: 8px; }
    .body p.sub { font-size: 14px; color: #8E717D; margin-bottom: 28px; }
    .otp-box { display: inline-block; background: #FFF0F3; border: 2px dashed #B5003F; border-radius: 16px; padding: 22px 40px; margin-bottom: 28px; }
    .otp-box span { font-size: 42px; font-weight: bold; letter-spacing: 10px; color: #B5003F; font-family: 'Courier New', monospace; }
    .note { font-size: 13px; color: #8E717D; margin-bottom: 8px; }
    .warning { font-size: 12px; color: #c0392b; margin-top: 4px; }
    .footer { background: #FFF5F7; padding: 20px 32px; text-align: center; }
    .footer p { font-size: 12px; color: #B5003F; margin: 0; }
    .heart { font-size: 20px; }

    @media only screen and (max-width: 480px) {
      .wrapper { margin: 20px 12px !important; border-radius: 16px !important; }
      .header { padding: 28px 20px !important; }
      .header h1 { font-size: 22px !important; }
      .body { padding: 28px 20px !important; }
      .otp-box { padding: 16px 20px !important; margin-bottom: 20px !important; border-radius: 12px !important; }
      .otp-box span { font-size: 30px !important; letter-spacing: 6px !important; }
      .footer { padding: 16px 20px !important; }
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <div class="heart">💕</div>
      <h1>Our Space</h1>
      <p>Email Verification Request</p>
    </div>
    <div class="body">
      <p class="greeting">Welcome to Our Space 💌</p>
      <p class="sub">Use the code below to verify your email and complete your sign up. It expires in <strong>15 minutes</strong>.</p>
      <div class="otp-box">
        <span>{{ $otp }}</span>
      </div>
      <p class="note">Enter this code in the app to continue.</p>
      <p class="warning">⚠️ If you didn't request this, please ignore this email.</p>
    </div>
    <div class="footer">
      <p>Sent with love by Our Space ❤️</p>
    </div>
  </div>
</body>
</html>
