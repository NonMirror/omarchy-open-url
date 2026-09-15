// Persistent recency cache for links opened through this plugin.
//
// Storage is a single JSON array of { url, accessed } where `accessed` is an
// epoch-milliseconds timestamp. Everything here is pure array work on a list
// that stays in memory for the life of the shell, so a keystroke never spawns
// a process or touches the disk: zoxide and fzf both cost a fork per query,
// and at a few hundred entries a linear scan in QML's own JS engine is
// microseconds. The file is only rewritten when a link is opened or an entry
// ages out.

// Two weeks. A link that has not been opened through the plugin for this long
// is dropped from the cache.
var TTL_MS = 14 * 24 * 60 * 60 * 1000

function parse(raw) {
  try {
    var parsed = JSON.parse(String(raw || "[]"))
    if (!Array.isArray(parsed)) return []

    var out = []
    for (var i = 0; i < parsed.length; i++) {
      var entry = parsed[i]
      if (!entry) continue
      var url = typeof entry === "string" ? entry : String(entry.url || "")
      if (!url) continue
      var accessed = typeof entry === "object" ? Number(entry.accessed) : 0
      if (!isFinite(accessed) || accessed < 0) accessed = 0
      out.push({ url: url, accessed: accessed })
    }
    return out
  } catch (e) {
    return []
  }
}

function serialize(entries) {
  var list = Array.isArray(entries) ? entries : []
  var out = []
  for (var i = 0; i < list.length; i++) {
    var entry = list[i]
    if (!entry || !entry.url) continue
    out.push({ url: entry.url, accessed: entry.accessed || 0 })
  }
  return JSON.stringify(out)
}

// Drop entries whose last access is older than the TTL. Returns the surviving
// list; callers compare lengths to learn whether anything aged out.
function prune(entries, now, ttlMs) {
  var list = Array.isArray(entries) ? entries : []
  var ttl = ttlMs === undefined || ttlMs === null ? TTL_MS : Number(ttlMs)
  var cutoff = now - ttl
  var out = []

  for (var i = 0; i < list.length; i++) {
    var entry = list[i]
    if (!entry || !entry.url) continue
    if ((entry.accessed || 0) < cutoff) continue
    out.push({ url: entry.url, accessed: entry.accessed || 0 })
  }
  return out
}

// Move a URL to the front with a fresh timestamp. The list is kept MRU-first,
// which is also the order the UI renders in, so no sort is needed on read.
function record(entries, url, now, limit) {
  var link = String(url || "")
  if (!link) return Array.isArray(entries) ? entries.slice() : []

  var max = limit === undefined || limit === null ? 500 : Number(limit)
  if (isNaN(max) || max < 0) max = 500

  var next = [{ url: link, accessed: now || 0 }]
  var list = Array.isArray(entries) ? entries : []
  for (var i = 0; i < list.length && next.length < max; i++) {
    var entry = list[i]
    if (!entry || !entry.url || entry.url === link) continue
    next.push({ url: entry.url, accessed: entry.accessed || 0 })
  }
  return next
}

function containsUrl(entries, url) {
  var link = String(url || "")
  var list = Array.isArray(entries) ? entries : []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].url === link) return true
  }
  return false
}

// Every whitespace-separated token must appear somewhere in the URL, so
// "nonmirror icu" and "icu" both match https://nonmirror.icu. Results are
// already MRU-first; sorting is a cheap no-op guard for imported files.
function matches(entries, query, limit) {
  var list = Array.isArray(entries) ? entries : []
  var needle = String(query || "").trim().toLowerCase()
  var max = limit === undefined || limit === null ? 50 : Number(limit)
  if (isNaN(max) || max < 0) max = 50

  var tokens = needle ? needle.split(/\s+/) : []
  var rows = []

  for (var i = 0; i < list.length; i++) {
    var entry = list[i]
    if (!entry || !entry.url) continue

    if (tokens.length > 0) {
      var haystack = entry.url.toLowerCase()
      var hit = true
      for (var t = 0; t < tokens.length; t++) {
        if (tokens[t] && haystack.indexOf(tokens[t]) < 0) { hit = false; break }
      }
      if (!hit) continue
    }

    rows.push({ url: entry.url, accessed: entry.accessed || 0 })
    if (rows.length >= max) break
  }

  rows.sort(function(a, b) { return b.accessed - a.accessed })
  return rows
}

// The scheme is noise in a compact suggestion list; keep it in the stored URL.
function displayUrl(url) {
  return String(url || "").replace(/^(?:https?|ftp):\/\//i, "")
}

function formatAge(accessed, now) {
  if (!accessed) return ""
  var delta = now - accessed
  if (delta < 0) delta = 0

  var minutes = Math.floor(delta / 60000)
  if (minutes < 1) return "just now"
  if (minutes < 60) return minutes + "m ago"

  var hours = Math.floor(minutes / 60)
  if (hours < 24) return hours + "h ago"

  return Math.floor(hours / 24) + "d ago"
}

if (typeof module !== "undefined") {
  module.exports = {
    TTL_MS: TTL_MS,
    parse: parse,
    serialize: serialize,
    prune: prune,
    record: record,
    containsUrl: containsUrl,
    matches: matches,
    displayUrl: displayUrl,
    formatAge: formatAge
  }
}
