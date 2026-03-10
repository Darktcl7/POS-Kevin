<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

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

        return response()->json([
            'users' => $users,
            'roles' => $roles,
            'outlets' => $outlets,
        ]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|string|min:6',
            'role_id' => 'required|exists:roles,id',
            'outlet_id' => 'required|exists:outlets,id',
        ]);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => Hash::make($data['password']),
            'role_id' => $data['role_id'],
            'outlet_id' => $data['outlet_id'],
            'is_active' => true,
        ]);

        return response()->json(['message' => 'User berhasil ditambahkan', 'user' => $user], 201);
    }

    public function toggleActive($id)
    {
        $user = User::findOrFail($id);
        $user->update(['is_active' => ! $user->is_active]);
        
        return response()->json([
            'message' => 'User ' . ($user->is_active ? 'diaktifkan' : 'dinonaktifkan')
        ]);
    }

    public function resetPassword(Request $request, $id)
    {
        $request->validate([
            'new_password' => 'required|string|min:6',
        ]);

        $user = User::findOrFail($id);
        $user->update(['password' => Hash::make($request->new_password)]);
        
        return response()->json(['message' => 'Password berhasil direset']);
    }

    public function destroy($id)
    {
        $user = User::findOrFail($id);
        
        if ($user->id === auth()->id()) {
            throw ValidationException::withMessages([
                'user' => ['Tidak bisa menghapus akun Anda sendiri.']
            ]);
        }

        $user->delete();
        return response()->json(['message' => 'User berhasil dihapus']);
    }
}
