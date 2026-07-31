<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class NewDeviceLoginMail extends Mailable
{
    use Queueable, SerializesModels;

    public string $deviceName;
    public string $ipAddress;
    public string $loginTime;

    /**
     * Create a new message instance.
     */
    public function __construct(string $deviceName, string $ipAddress, string $loginTime)
    {
        $this->deviceName = $deviceName;
        $this->ipAddress = $ipAddress;
        $this->loginTime = $loginTime;
    }

    /**
     * Get the message envelope.
     */
    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Security Alert: New Device Login to Our Space',
        );
    }

    /**
     * Get the message content definition.
     */
    public function content(): Content
    {
        return new Content(
            view: 'emails.new_device_login',
            text: 'emails.new_device_login_text',
            with: [
                'deviceName' => $this->deviceName,
                'ipAddress' => $this->ipAddress,
                'loginTime' => $this->loginTime,
            ],
        );
    }

    /**
     * Add anti-spam headers.
     */
    public function build(): static
    {
        return $this->withSymfonyMessage(function (\Symfony\Component\Mime\Email $message) {
            $message->getHeaders()
                ->addTextHeader('X-Mailer', 'Our Space Mailer')
                ->addTextHeader('X-Auto-Response-Suppress', 'OOF, AutoReply');
        });
    }

    /**
     * Get the attachments for the message.
     */
    public function attachments(): array
    {
        return [];
    }
}
