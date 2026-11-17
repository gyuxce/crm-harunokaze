'use server'

import { getLaporanBulananData } from '@/server/laporan-bulanan'

export async function loadLaporanBulanan() {
  return getLaporanBulananData()
}
