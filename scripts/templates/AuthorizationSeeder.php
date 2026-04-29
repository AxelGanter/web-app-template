<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

class AuthorizationSeeder extends Seeder
{
    public function run(): void
    {
        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        $this->ensureInitialAdmin();
    }

    private function ensureInitialAdmin(): void
    {
        $email = env('CCC_ADMIN_EMAIL', 'admin@example.com');
        $password = env('CCC_ADMIN_PASSWORD');

        $attributes = [
            'name' => env('CCC_ADMIN_NAME', 'Admin'),
            'email_verified_at' => now(),
        ];

        if ($password !== null && $password !== '') {
            $attributes['password'] = Hash::make($password);
        }

        $user = User::firstOrCreate(
            ['email' => $email],
            $attributes + ['password' => Hash::make(str()->password(32))]
        );

        if (! $user->wasRecentlyCreated) {
            $user->forceFill($attributes)->save();
        }
    }
}
