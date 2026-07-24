<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Connect on Aura</title>
    <style>
        body {
            background-color: #FFF5F7;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            margin: 0;
            padding: 40px 20px;
            color: #2C1820;
            line-height: 1.6;
        }
        .container {
            max-width: 500px;
            margin: 0 auto;
            background: #ffffff;
            padding: 40px;
            border-radius: 24px;
            box-shadow: 0 10px 30px rgba(181, 0, 63, 0.05);
            text-align: center;
        }
        .heart-badge {
            width: 70px;
            height: 70px;
            background-color: #FFF5F7;
            border-radius: 50%;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 24px;
        }
        .heart-icon {
            font-size: 32px;
            color: #B5003F;
        }
        h1 {
            font-family: "Georgia", serif;
            font-size: 24px;
            font-weight: bold;
            color: #B5003F;
            margin: 0 0 16px 0;
        }
        p {
            font-size: 15px;
            color: #64748B;
            margin: 0 0 24px 0;
        }
        strong {
            color: #2C1820;
        }
        .action-button {
            display: inline-block;
            background-color: #B5003F;
            color: #ffffff !important;
            text-decoration: none;
            padding: 16px 36px;
            border-radius: 30px;
            font-weight: bold;
            font-size: 15px;
            margin-bottom: 24px;
            box-shadow: 0 4px 10px rgba(181, 0, 63, 0.2);
            transition: all 0.2s ease-in-out;
        }
        .footer {
            font-size: 12px;
            color: #94A3B8;
            margin-top: 32px;
            border-top: 1px solid #F1F5F9;
            padding-top: 24px;
        }
        .footer-logo {
            font-family: "Georgia", serif;
            font-weight: bold;
            color: #B5003F;
            font-size: 14px;
            margin-bottom: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="heart-badge">
            <span class="heart-icon">♥</span>
        </div>
        
        <h1>Connect with {{ $senderName }}</h1>
        
        <p>
            Your partner, <strong>{{ $senderName }}</strong>, has invited you to connect on <strong>Aura</strong>, the private couples space where hearts stay connected.
        </p>
        
        <p>
            Once you register, your accounts will be automatically paired, allowing you to instantly share live real-time chats, propose date plans, and count your special days together!
        </p>
        
        <a href="http://localhost:8000" class="action-button">Join Aura Now</a>
        
        <div class="footer">
            <div class="footer-logo">Aura</div>
            <div>Where hearts connect • Premium Digital Tenderness</div>
        </div>
    </div>
</body>
</html>
