<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class InitialPosSeeder extends Seeder
{
    public function run()
    {
        $now = now();

        $roles = ['Owner', 'Manager', 'Kasir', 'Barista', 'Admin Gudang'];
        foreach ($roles as $roleName) {
            DB::table('roles')->updateOrInsert(
                ['role_name' => $roleName],
                ['updated_at' => $now, 'created_at' => $now]
            );
        }

        DB::table('outlets')->updateOrInsert(
            ['outlet_name' => 'Outlet Utama'],
            [
                'address' => 'Alamat belum diisi',
                'phone' => '0800000000',
                'is_active' => true,
                'updated_at' => $now,
                'created_at' => $now,
            ]
        );

        $outletId = DB::table('outlets')->where('outlet_name', 'Outlet Utama')->value('id');
        $ownerRoleId = DB::table('roles')->where('role_name', 'Owner')->value('id');

        DB::table('warehouses')->updateOrInsert(
            ['outlet_id' => $outletId, 'warehouse_name' => 'Main Warehouse'],
            [
                'is_main' => true,
                'updated_at' => $now,
                'created_at' => $now,
            ]
        );

        DB::table('users')->updateOrInsert(
            ['email' => 'owner@poskevin.local'],
            [
                'name' => 'Owner POS',
                'password' => Hash::make('password123'),
                'role_id' => $ownerRoleId,
                'outlet_id' => $outletId,
                'is_active' => true,
                'updated_at' => $now,
                'created_at' => $now,
            ]
        );
    }
}
