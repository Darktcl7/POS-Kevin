<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use App\Models\User;

class UserController extends Controller
{
    public function index()
    {
        $users = User::orderBy('name')->get()->map(function ($user) {
            $user->role_display = DB::table('roles')->where('id', $user->role_id)->value('role_name') ?? '-';
            $user->outlet_display = DB::table('outlets')->where('id', $user->outlet_id)->value('outlet_name') ?? '-';
            return $user;
        });

        $roles = DB::table('roles')->orderBy('role_name')->get();
        $outlets = DB::table('outlets')->where('is_active', true)->orderBy('outlet_name')->get();

        return view('admin.users.index', compact('users', 'roles', 'outlets'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|string|min:6',
            'role_id' => 'required|exists:roles,id',
            'outlet_id' => 'required|exists:outlets,id',
        ]);

        User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role_id' => $request->role_id,
            'outlet_id' => $request->outlet_id,
            'is_active' => true,
        ]);

        return redirect()->route('admin.users.index')->with('success', 'User berhasil ditambahkan!');
    }

    public function toggleActive(User $user)
    {
        $user->update(['is_active' => ! $user->is_active]);
        $status = $user->is_active ? 'diaktifkan' : 'dinonaktifkan';
        return redirect()->route('admin.users.index')->with('success', "User {$user->name} berhasil {$status}!");
    }

    public function resetPassword(Request $request, User $user)
    {
        $request->validate([
            'new_password' => 'required|string|min:6',
        ]);

        $user->update(['password' => Hash::make($request->new_password)]);
        return redirect()->route('admin.users.index')->with('success', "Password {$user->name} berhasil direset!");
    }

    public function destroy(User $user)
    {
        if ($user->id === auth()->id()) {
            return redirect()->route('admin.users.index')->with('error', 'Tidak bisa menghapus akun sendiri!');
        }

        $user->delete();
        return redirect()->route('admin.users.index')->with('success', "User {$user->name} berhasil dihapus!");
    }
}
