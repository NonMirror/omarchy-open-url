// Recognize the shapes a URL actually takes: an explicit scheme, a `www.`
// host, an IPv4/localhost authority, or a bare host. A bare host with no path
// or port must end in a plausible TLD (the allowlist below or a two-letter
// ccTLD), otherwise ids like `system.power` and filenames like `notes.txt`
// would be handed to the browser. A path or port is itself a strong URL signal,
// so those skip the allowlist check and cover long/rare TLDs.
var URL_TLDS = {
  com: 1, org: 1, net: 1, edu: 1, gov: 1, mil: 1, int: 1,
  io: 1, dev: 1, app: 1, co: 1, ai: 1, me: 1, xyz: 1, info: 1,
  biz: 1, tv: 1, cloud: 1, site: 1, online: 1, store: 1, tech: 1,
  blog: 1, wiki: 1, news: 1, live: 1, one: 1, run: 1, sh: 1,
  gg: 1, ly: 1, to: 1, fm: 1,
  icu: 1, top: 1, vip: 1, club: 1, work: 1, life: 1, world: 1, fun: 1,
  shop: 1, art: 1, design: 1, space: 1, website: 1, press: 1, host: 1,
  page: 1, studio: 1, agency: 1, digital: 1, media: 1, email: 1, group: 1,
  team: 1, plus: 1, chat: 1, link: 1, click: 1, today: 1, zone: 1, city: 1,
  land: 1, house: 1, farm: 1, cafe: 1, bar: 1, pub: 1, school: 1, academy: 1,
  university: 1, college: 1, institute: 1, guru: 1, expert: 1, pro: 1,
  tips: 1, name: 1, mobi: 1, asia: 1, cat: 1, jobs: 1, travel: 1, museum: 1,
  aero: 1, coop: 1, tel: 1, xxx: 1
}

// Returns a URL ready for the browser, or "" when the text is not one.
function normalizeUrl(value) {
  var text = String(value || "").trim()
  if (!text || /\s/.test(text)) return ""

  if (/^(?:https?|ftp):\/\/\S+$/i.test(text)) return text
  if (/^www\.[^\s/?#]+\.[^\s/?#]+/i.test(text)) return "https://" + text
  if (/^localhost(?::\d{1,5})?(?:[/?#]\S*)?$/i.test(text)) return "http://" + text

  var authority = text
  var pathAt = text.search(/[/?#]/)
  if (pathAt >= 0) authority = text.slice(0, pathAt)
  var hasPathOrPort = pathAt >= 0 || /:\d{1,5}$/.test(authority)
  var host = authority.replace(/:\d{1,5}$/, "")

  if (/^\d{1,3}(?:\.\d{1,3}){3}$/.test(host)) return "https://" + text
  if (!/^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,24}$/i.test(host)) return ""

  var tld = host.slice(host.lastIndexOf(".") + 1).toLowerCase()
  if (tld.length !== 2 && !URL_TLDS[tld] && !hasPathOrPort) return ""

  return "https://" + text
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeUrl: normalizeUrl
  }
}
