<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class OtpMail extends Mailable
{
    use Queueable, SerializesModels;

    public string $otp;

    /**
     * Create a new message instance.
     */
    public function __construct(string $otp)
    {
        $this->otp = $otp;
    }

    /**
     * Get the message envelope.
     */
    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Your Our Space Password Reset Code',
        );
    }

    /**
     * Get the message content definition.
     */
    public function content(): Content
    {
        return new Content(
            view: 'emails.otp',
            text: 'emails.otp_text',
            with: ['otp' => $this->otp],
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
