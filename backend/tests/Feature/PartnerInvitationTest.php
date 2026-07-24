<?php

namespace Tests\Feature;

use App\Models\User;
use App\Mail\PartnerInvitationMail;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class PartnerInvitationTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_sends_partner_invitation_email_when_pairing_pending_partner()
    {
        Mail::fake();

        // Create inviting user
        $user = User::factory()->create([
            'name' => 'Arun'
        ]);

        // Request pairing with a non-existent partner
        $partnerEmail = 'vaishali_pending@example.com';
        
        $response = $this->actingAs($user)
            ->postJson('/api/pair-partner', [
                'partner_email' => $partnerEmail,
            ]);

        $response->assertStatus(200);
        $response->assertJsonFragment([
            'pending_partner_email' => $partnerEmail,
        ]);

        // Assert mail was sent to pending partner
        Mail::assertSent(PartnerInvitationMail::class, function ($mail) use ($partnerEmail) {
            return $mail->hasTo($partnerEmail) && 
                   $mail->senderName === 'Arun' &&
                   $mail->envelope()->subject === 'Connect with Arun on Aura ♡';
        });
    }

    public function test_mailable_contains_invitation_text()
    {
        $mail = new PartnerInvitationMail('Arun');

        $mail->assertSeeInHtml('Connect with Arun');
        $mail->assertSeeInHtml('Your partner');
        $mail->assertSeeInHtml('has invited you to connect on');
    }
}
