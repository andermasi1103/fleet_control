export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function stringValue(value: unknown, max: number, required = true): string | null {
  if (value === undefined || value === null) return required ? null : '';
  if (typeof value !== 'string') return null;
  const result = value.trim();
  return (required && result.length === 0) || result.length > max ? null : result;
}

export function optionalString(value: unknown, max: number): string | null | undefined {
  if (value === undefined) return undefined;
  if (value === null) return null;
  return stringValue(value, max, false) ?? undefined;
}

export function numberValue(value: unknown, min: number, max: number): number | null {
  return typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max ? value : null;
}

export function isUuid(value: unknown): value is string {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

export function limitOffset(search: URLSearchParams): { limit: number; offset: number } | null {
  const limit = Number(search.get('limit') ?? 50);
  const offset = Number(search.get('offset') ?? 0);
  return Number.isInteger(limit) && limit > 0 && limit <= 100 && Number.isInteger(offset) && offset >= 0 ? { limit, offset } : null;
}

export function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const radians = (degrees: number) => degrees * Math.PI / 180;
  const dLat = radians(lat2 - lat1);
  const dLon = radians(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(radians(lat1)) * Math.cos(radians(lat2)) * Math.sin(dLon / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function relatedName(value: unknown): string | null {
  const related = Array.isArray(value) ? value[0] : value;
  return typeof related === 'object' && related !== null && 'nombre' in related && typeof related.nombre === 'string'
    ? related.nombre
    : null;
}

export function relatedCode(value: unknown): string | null {
  const related = Array.isArray(value) ? value[0] : value;
  return typeof related === 'object' && related !== null && 'codigo' in related && typeof related.codigo === 'string'
    ? related.codigo
    : null;
}
