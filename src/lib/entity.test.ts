import { describe, expect, it } from 'vitest'
import { getEntityForCampaign, resolveEntity, type Entity } from './entity'

// Aturan ini juga ditiru persis di SQL pembersihan (db/one-off/2026-11-17_cleanup-kfi-stage3).
// Kalau salah satunya berubah, ubah keduanya.

describe('getEntityForCampaign (tebakan)', () => {
  it.each(['Program Driver Jepang', 'program driver jepang', 'DRIVER UPPER'])('%s -> KFI', (c) => {
    expect(getEntityForCampaign(c)).toBe('KFI')
  })

  it.each(['Campaign Construction 3', 'Ads Import', 'Webinar 7'])('%s -> HNZ', (c) => {
    expect(getEntityForCampaign(c)).toBe('HNZ')
  })

  it('null / undefined / kosong -> HNZ', () => {
    expect(getEntityForCampaign(null)).toBe('HNZ')
    expect(getEntityForCampaign(undefined)).toBe('HNZ')
    expect(getEntityForCampaign('')).toBe('HNZ')
  })
})

describe('resolveEntity (override menang atas tebakan)', () => {
  const overrides = new Map<string, Entity>([
    ['Program Driver Jepang', 'KFI'],
    ['Driver Mod', 'HNZ'], // mengandung "driver" tapi sengaja di-assign HNZ
    ['Konstruksi X', 'KFI'], // tanpa kata "driver" tapi sengaja di-assign KFI
  ])

  it('override HNZ mengalahkan kata "driver"', () => {
    expect(resolveEntity('Driver Mod', overrides)).toBe('HNZ')
  })

  it('override KFI mengalahkan nama tanpa "driver"', () => {
    expect(resolveEntity('Konstruksi X', overrides)).toBe('KFI')
  })

  it('campaign belum di-assign memakai tebakan', () => {
    expect(resolveEntity('program driver jepang', overrides)).toBe('KFI')
    expect(resolveEntity('Ads Import', overrides)).toBe('HNZ')
  })

  it('pencocokan override persis: beda spasi / huruf besar tidak cocok', () => {
    expect(resolveEntity('Konstruksi X ', overrides)).toBe('HNZ')
    expect(resolveEntity('konstruksi x', overrides)).toBe('HNZ')
  })

  it('campaign null -> HNZ', () => {
    expect(resolveEntity(null, overrides)).toBe('HNZ')
  })
})
