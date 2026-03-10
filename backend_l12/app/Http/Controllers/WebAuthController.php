<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class WebAuthController extends Controller
{
    public function showLogin()
    {
        if (Auth::check()) {
            return redirect()->route('admin.dashboard');
        }
        return view('admin.login');
    }

    public function login(Request $request)
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required'],
        ]);

        if (Auth::attempt($credentials, $request->boolean('remember'))) {
            $user = Auth::user();

            // Check if account is active
            if (! $user->is_active) {
                Auth::logout();
                return back()->withErrors([
                    'email' => 'Akun Anda dinonaktifkan. Hubungi Owner untuk mengaktifkan kembali.',
                ])->onlyInput('email');
            }

            // Check if user has admin access (Owner/Manager)
            if (! $user->isAdmin()) {
                Auth::logout();
                return back()->withErrors([
                    'email' => 'Akun Anda tidak memiliki hak akses ke Admin Dashboard. Hanya Owner/Manager yang diizinkan.',
                ])->onlyInput('email');
            }

            $request->session()->regenerate();
            return redirect()->intended(route('admin.dashboard'));
        }

        return back()->withErrors([
            'email' => 'Email atau password yang Anda masukkan salah.',
        ])->onlyInput('email');
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();
        return redirect()->route('admin.login');
    }
}
