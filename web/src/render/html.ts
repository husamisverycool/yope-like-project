// HTML escaping for text and attribute values. Every value that comes from the database (group
// name, first names) or from the request goes through esc().

const MAP: Record<string, string> = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };

export const esc = (s: string): string => s.replace(/[&<>"']/g, (c) => MAP[c]!);
