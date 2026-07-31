<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Connect Hearts – Our Space</title>
  <style>
    body { margin: 0; padding: 0; background: #FFF5F7; font-family: 'Georgia', serif; }
    .wrapper { max-width: 520px; margin: 40px auto; background: #ffffff; border-radius: 20px; overflow: hidden; box-shadow: 0 4px 24px rgba(181,0,63,0.08); }
    .header { background: linear-gradient(135deg, #B5003F 0%, #8A003D 100%); padding: 36px 32px; text-align: center; }
    .header .emoji { font-size: 36px; display: block; margin-bottom: 10px; }
    .header h1 { margin: 0; color: #ffffff; font-size: 26px; letter-spacing: 1px; }
    .header p  { margin: 6px 0 0; color: rgba(255,255,255,0.8); font-size: 13px; letter-spacing: 0.5px; }
    .body { padding: 36px 32px; text-align: center; }
    .body .greeting { font-size: 20px; color: #2C1820; font-weight: bold; margin-bottom: 12px; }
    .body .message { font-size: 15px; color: #8E717D; line-height: 1.7; margin-bottom: 28px; }
    .body .message strong { color: #B5003F; }
    .cta-button {
      display: inline-block;
      background: linear-gradient(135deg, #B5003F, #8A003D);
      color: #ffffff !important;
      text-decoration: none;
      padding: 16px 40px;
      border-radius: 30px;
      font-size: 15px;
      font-weight: bold;
      letter-spacing: 0.5px;
      box-shadow: 0 4px 16px rgba(181,0,63,0.25);
      margin-bottom: 28px;
    }
    .note { font-size: 12px; color: #B5003F; margin-top: 8px; }
    .steps { text-align: left; background: #FFF5F7; border-radius: 14px; padding: 20px 24px; margin: 24px 0; }
    .steps p { font-size: 13px; color: #2C1820; margin: 6px 0; }
    .steps p span { color: #B5003F; font-weight: bold; margin-right: 8px; }
    .footer { background: #FFF5F7; padding: 20px 32px; text-align: center; }
    .footer p { font-size: 12px; color: #B5003F; margin: 0; }

    @media only screen and (max-width: 480px) {
      .wrapper { margin: 20px 12px !important; border-radius: 16px !important; }
      .header { padding: 28px 20px !important; }
      .header h1 { font-size: 22px !important; }
      .body { padding: 28px 20px !important; }
      .body .greeting { font-size: 17px !important; }
      .body .message { font-size: 14px !important; line-height: 1.6 !important; margin-bottom: 20px !important; }
      .cta-button { padding: 14px 28px !important; font-size: 14px !important; margin-bottom: 20px !important; }
      .footer { padding: 16px 20px !important; }
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <span class="emoji">💕</span>
      <h1>Our Space</h1>
      <p>Your private couples universe</p>
    </div>
    <div class="body">
      <p class="greeting">Someone special is waiting for you!</p>
      <p class="message">
        <strong>{{ $senderName }}</strong> has invited you to connect on <strong>Our Space</strong>
        the private app built just for the two of you. Share moments, plan meet-ups, and stay close no matter the distance.
      </p>

      <p>Sent with love by Our Space ❤️ · Where hearts connect</p>
    </div>
  </div>
</body>
</html>
