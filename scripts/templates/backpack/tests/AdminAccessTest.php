<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Spatie\Permission\Models\Role;
use Tests\TestCase;

class AdminAccessTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_role_can_open_backpack(): void
    {
        $admin = User::factory()->create();
        $admin->assignRole(Role::create(['name' => 'admin', 'guard_name' => 'web']));

        $this->actingAs($admin, 'backpack')->get('/admin/dashboard')->assertOk();
    }

    public function test_regular_user_cannot_open_backpack(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user, 'backpack')
            ->get('/admin/dashboard')
            ->assertRedirect('/admin/login');
    }

    public function test_public_admin_registration_is_closed(): void
    {
        $this->get('/admin/register')->assertForbidden();
    }
}
