<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthApiTest extends TestCase
{
    use RefreshDatabase;

    private function spaHeaders(): array
    {
        return [
            'Accept' => 'application/json',
            'X-Requested-With' => 'XMLHttpRequest',
        ];
    }

    private function fromSpa(): self
    {
        $frontendUrl = rtrim(env('FRONTEND_APP_URL', 'http://localhost:3101'), '/');

        return $this->withServerVariables([
            'HTTP_ORIGIN' => $frontendUrl,
            'HTTP_REFERER' => $frontendUrl.'/',
        ]);
    }

    public function test_csrf_cookie_endpoint_is_available(): void
    {
        $this->get('/sanctum/csrf-cookie')
            ->assertNoContent();
    }

    public function test_authenticated_user_endpoint_requires_login(): void
    {
        $this->getJson('/api/auth/user')
            ->assertUnauthorized();
    }

    public function test_login_validation_rejects_invalid_credentials(): void
    {
        $this->postJson('/api/auth/login', [
            'email' => 'missing@example.test',
            'password' => 'wrong-password',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_user_can_login_read_session_user_and_logout(): void
    {
        $user = User::factory()->create([
            'password' => Hash::make('correct-password'),
        ]);

        $this->fromSpa()->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => 'correct-password',
            'remember' => true,
        ], $this->spaHeaders())->assertOk()
            ->assertJsonPath('user.email', $user->email);

        $this->fromSpa()->getJson('/api/auth/user', $this->spaHeaders())
            ->assertOk()
            ->assertJsonPath('user.email', $user->email);

        $this->fromSpa()->postJson('/api/auth/logout', [], $this->spaHeaders())
            ->assertOk()
            ->assertJsonPath('ok', true);
    }
}
