<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureIsAdmin
{
    /**
     * Only allow Owner or Manager to access the admin panel.
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (! $request->user() || ! $request->user()->isAdmin()) {
            if ($request->expectsJson()) {
                return response()->json(['message' => 'Forbidden. Hanya Owner/Manager yang bisa akses.'], 403);
            }
            abort(403, 'Anda tidak memiliki akses ke halaman ini. Hanya Owner atau Manager yang diizinkan.');
        }

        return $next($request);
    }
}
