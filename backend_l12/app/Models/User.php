<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use App\Models\Role;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'role_id',
        'outlet_id',
        'name',
        'email',
        'password',
        'is_active',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'email_verified_at' => 'datetime',
        'is_active' => 'boolean',
    ];

    public function getRoleAttribute()
    {
        return \Illuminate\Support\Facades\DB::table('roles')->where('id', $this->role_id)->first() ?? ['name' => 'Unknown'];
    }

    /**
     * Get role name from the roles table.
     */
    public function getRoleNameAttribute(): string
    {
        return \Illuminate\Support\Facades\DB::table('roles')->where('id', $this->role_id)->value('role_name') ?? 'Unknown';
    }

    public function isOwner(): bool
    {
        return $this->role_name === 'Owner';
    }

    public function isManager(): bool
    {
        return $this->role_name === 'Manager';
    }

    public function isKasir(): bool
    {
        return $this->role_name === 'Kasir';
    }

    /**
     * Check if user has admin-level access (Owner or Manager).
     */
    public function isAdmin(): bool
    {
        return in_array($this->role_name, ['Owner', 'Manager']);
    }
}
