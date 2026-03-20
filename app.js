import { useState, useEffect, useCallback, useRef } from "react";

// ── DESIGN TOKENS ──────────────────────────────────────────────
const DARK = {
  bg: "#080808", surface: "#111113", card: "#18181C", border: "#262630",
  gold: "#C9A84C", goldLight: "#E8C97A", goldDim: "#6A5520",
  text: "#F0EDE8", textSec: "#9A9490", textDim: "#4A4845",
  red: "#E05252", green: "#52C87A", blue: "#5290E0",
};
const LIGHT = {
  bg: "#F2EFE8", surface: "#FFFFFF", card: "#FAF8F3", border: "#E4DDD0",
  gold: "#9A7020", goldLight: "#C9A84C", goldDim: "#D4B96A",
  text: "#1A1610", textSec: "#5A5040", textDim: "#A09080",
  red: "#C03030", green: "#2A8A50", blue: "#2060B0",
};

const CATEGORIES = [
  { id: "all", label: "🔥 Trending", slug: "" },
  { id: "biography", label: "📖 Biography", slug: "biography" },
  { id: "celebrity-news", label: "⭐ Celebrity", slug: "celebrity-news" },
  { id: "startup-founders-innovator", label: "💡 Innovators", slug: "startup-founders-innovator" },
  { id: "around-the-web", label: "🌐 Around Web", slug: "around-the-web" },
  { id: "money-career", label: "💰 Money", slug: "money-career" },
  { id: "reviews", label: "⭐ Reviews", slug: "reviews" },
];

const TRENDING_TAGS = ["#Nollywood","#Bollywood","#BBNaija","#TechAfrica","#Celebrity","#Biography","#Startup","#Nigeria","#Hollywood","#Music"];

const BASE = "https://allbiohub.com/wp-json/wp/v2";

// ── API HELPERS ────────────────────────────────────────────────
async function fetchPosts({ category="", search="", page=1, perPage=10 }={}) {
  let url = `${BASE}/posts?_embed&per_page=${perPage}&page=${page}&orderby=date&order=desc`;
  if (search) url += `&search=${encodeURIComponent(search)}`;
  if (category) {
    try {
      const r = await fetch(`${BASE}/categories?slug=${category}`);
      const cats = await r.json();
      if (cats.length) url += `&categories=${cats[0].id}`;
    } catch {}
  }
  const res = await fetch(url);
  const total = parseInt(res.headers.get("X-WP-Total")||"0");
  const posts = await res.json();
  return { posts: Array.isArray(posts) ? posts : [], total };
}

function stripHtml(html="") {
  return html.replace(/<[^>]*>/g,"").replace(/&[a-z0-9#]+;/gi,e=>{
    const m={"&amp;":"&","&lt;":"<","&gt;":">","&nbsp;":" ","&#8217;":"'","&#8216;":"'","&#8220;":'"',"&#8221;":'"',"&#8211;":"–","&#8212;":"—"};
    return m[e]||" ";
  }).trim();
}

function getThumb(post) {
  try {
    const m = post._embedded?.["wp:featuredmedia"]?.[0];
    return m?.media_details?.sizes?.medium_large?.source_url || m?.media_details?.sizes?.medium?.source_url || m?.source_url || null;
  } catch { return null; }
}
function getCategory(post) {
  try { return post._embedded?.["wp:term"]?.[0]?.[0]?.name||""; } catch { return ""; }
}
function getAuthor(post) {
  try { return post._embedded?.author?.[0]?.name||"AllBioHub"; } catch { return "AllBioHub"; }
}
function getAuthorAvatar(post) {
  try { return post._embedded?.author?.[0]?.avatar_urls?.["48"]||null; } catch { return null; }
}
function timeAgo(date) {
  const s = Math.floor((Date.now()-new Date(date))/1000);
  if(s<60) return "just now";
  if(s<3600) return `${Math.floor(s/60)}m ago`;
  if(s<86400) return `${Math.floor(s/3600)}h ago`;
  if(s<604800) return `${Math.floor(s/86400)}d ago`;
  return new Date(date).toLocaleDateString("en-US",{month:"short",day:"numeric",year:"numeric"});
}
function readTime(post) {
  const words = stripHtml((post.content?.rendered||post.excerpt?.rendered||"")).split(/\s+/).length;
  return Math.max(1, Math.ceil(words/200));
}

// ── ICONS ──────────────────────────────────────────────────────
const IC = ({ n, size=20, color="#C9A84C", fill="none" }) => {
  const paths = {
    home: <><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z" fill={fill}/><polyline points="9 22 9 12 15 12 15 22"/></>,
    search: <><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></>,
    bm: <path d="M19 21l-7-5-7 5V5a2 2 0 012-2h10a2 2 0 012 2z" fill={fill}/>,
    info: <><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></>,
    sun: <><circle cx="12" cy="12" r="5"/><line x1="12" y1="1" x2="12" y2="3"/><line x1="12" y1="21" x2="12" y2="23"/><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"/><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"/><line x1="1" y1="12" x2="3" y2="12"/><line x1="21" y1="12" x2="23" y2="12"/><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"/><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"/></>,
    moon: <path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/>,
    share: <><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/></>,
    back: <><line x1="19" y1="12" x2="5" y2="12"/><polyline points="12 19 5 12 12 5"/></>,
    ext: <><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></>,
    bell: <><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></>,
    fire: <path d="M12 2s-4 4-4 9a4 4 0 008 0c0-3-1.5-5.5-2-7-.5 1.5-1 3-2 4.5C11 6.5 12 2 12 2z" fill={color}/>,
    x: <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-4.714-6.231-5.401 6.231H2.745l7.73-8.835L1.254 2.25H8.08l4.253 5.622zm-1.161 17.52h1.833L7.084 4.126H5.117z" fill={color} stroke="none"/>,
    wa: <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" fill={color} stroke="none"/>,
    fb: <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" fill={color} stroke="none"/>,
    copy: <><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></>,
    clock: <><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></>,
    user: <><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></>,
    refresh: <><polyline points="23 4 23 10 17 10"/><path d="M20.49 15a9 9 0 11-2.12-9.36L23 10"/></>,
    trending: <><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></>,
    tag: <><path d="M20.59 13.41l-7.17 7.17a2 2 0 01-2.83 0L2 12V2h10l8.59 8.59a2 2 0 010 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></>,
    wifi: <><path d="M5 12.55a11 11 0 0114.08 0"/><path d="M1.42 9a16 16 0 0121.16 0"/><path d="M8.53 16.11a6 6 0 016.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></>,
    text: <><line x1="17" y1="10" x2="3" y2="10"/><line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="14" x2="3" y2="14"/><line x1="17" y1="18" x2="3" y2="18"/></>,
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      {paths[n]}
    </svg>
  );
};

// ══════════════════════════════════════════════════════════════
// MAIN APP
// ══════════════════════════════════════════════════════════════
export default function AllBioHubApp() {
  const [dark, setDark] = useState(true);
  const [tab, setTab] = useState("home");
  const [activeCat, setActiveCat] = useState("all");
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [total, setTotal] = useState(0);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState([]);
  const [searching, setSearching] = useState(false);
  const [bookmarks, setBookmarks] = useState([]);
  const [readHistory, setReadHistory] = useState([]);
  const [selectedPost, setSelectedPost] = useState(null);
  const [authorPost, setAuthorPost] = useState(null);
  const [authorPosts, setAuthorPosts] = useState([]);
  const [authorLoading, setAuthorLoading] = useState(false);
  const [sharePost, setSharePost] = useState(null);
  const [notification, setNotification] = useState(null);
  const [featuredPost, setFeaturedPost] = useState(null);
  const [mostRead, setMostRead] = useState([]);
  const [fontSize, setFontSize] = useState("medium");
  const [showSettings, setShowSettings] = useState(false);
  const [notifEnabled, setNotifEnabled] = useState(true);
  const [activeTag, setActiveTag] = useState(null);
  const [offlinePosts, setOfflinePosts] = useState([]);
  const [isOffline, setIsOffline] = useState(false);
  const [cache] = useState({});
  const searchTimeout = useRef(null);
  const pullStartY = useRef(0);
  const C = dark ? DARK : LIGHT;
  const FONT_SIZES = { small: 13, medium: 15, large: 17 };
  const bodySize = FONT_SIZES[fontSize];

  // ── NETWORK ────────────────────────────────────────────────
  useEffect(() => {
    const on = () => setIsOffline(false);
    const off = () => setIsOffline(true);
    window.addEventListener("online", on);
    window.addEventListener("offline", off);
    setIsOffline(!navigator.onLine);
    return () => { window.removeEventListener("online", on); window.removeEventListener("offline", off); };
  }, []);

  // ── LOAD POSTS ─────────────────────────────────────────────
  const loadPosts = useCallback(async (reset=false, cat=activeCat, pg=1) => {
    if (reset) setLoading(true); else setLoadingMore(true);
    try {
      const slug = CATEGORIES.find(c=>c.id===cat)?.slug||"";
      const key = `${cat}-${pg}`;
      let newPosts, t;
      if (cache[key]) { ({ posts: newPosts, total: t } = cache[key]); }
      else {
        const res = await fetchPosts({ category: slug, page: pg, perPage: 10 });
        newPosts = res.posts; t = res.total;
        cache[key] = { posts: newPosts, total: t };
        if (pg===1) setOfflinePosts(newPosts.slice(0,20));
      }
      setTotal(t);
      if (reset) {
        setPosts(newPosts);
        if (newPosts.length>0) { setFeaturedPost(newPosts[0]); setMostRead(newPosts.slice(1,6)); }
      } else { setPosts(p=>[...p,...newPosts]); }
      setHasMore(pg*10<t);
    } catch {
      if (offlinePosts.length>0) { setPosts(offlinePosts); showNotif("Showing cached content (offline)","warn"); }
      else showNotif("Failed to load. Check connection.","error");
    } finally { setLoading(false); setLoadingMore(false); setRefreshing(false); }
  }, [activeCat, cache, offlinePosts]);

  useEffect(() => { setPage(1); loadPosts(true, activeCat, 1); }, [activeCat]);

  const loadMore = () => { if(!loadingMore&&hasMore){const np=page+1;setPage(np);loadPosts(false,activeCat,np);} };

  const handleRefresh = async () => {
    setRefreshing(true);
    Object.keys(cache).forEach(k=>delete cache[k]);
    setPage(1); await loadPosts(true,activeCat,1);
    showNotif("Feed refreshed ✓");
  };

  // ── SEARCH ─────────────────────────────────────────────────
  useEffect(() => {
    if (!searchQuery.trim()) { setSearchResults([]); return; }
    clearTimeout(searchTimeout.current);
    searchTimeout.current = setTimeout(async () => {
      setSearching(true);
      try { const { posts: r } = await fetchPosts({ search: searchQuery, perPage: 20 }); setSearchResults(r); }
      catch { setSearchResults([]); }
      finally { setSearching(false); }
    }, 500);
  }, [searchQuery]);

  // ── TAG ────────────────────────────────────────────────────
  const handleTag = (tag) => {
    setActiveTag(tag); setTab("search");
    setSearchQuery(tag.replace("#",""));
  };

  // ── BOOKMARKS ──────────────────────────────────────────────
  const toggleBM = (post) => {
    setBookmarks(bm => {
      const exists = bm.find(b=>b.id===post.id);
      if(exists){showNotif("Removed from bookmarks");return bm.filter(b=>b.id!==post.id);}
      showNotif("Saved to bookmarks ✓"); return [post,...bm];
    });
  };
  const isBM = (id) => bookmarks.some(b=>b.id===id);

  // ── HISTORY ────────────────────────────────────────────────
  const openPost = (post) => {
    setSelectedPost(post);
    setReadHistory(h=>[post,...h.filter(p=>p.id!==post.id)].slice(0,10));
  };

  // ── AUTHOR ─────────────────────────────────────────────────
  const openAuthor = async (post) => {
    setAuthorPost(post); setAuthorLoading(true);
    try {
      const { posts: ap } = await fetchPosts({ perPage: 20 });
      setAuthorPosts(ap.slice(0,8));
    } catch { setAuthorPosts([]); }
    finally { setAuthorLoading(false); }
  };

  // ── TOAST ──────────────────────────────────────────────────
  const showNotif = (msg, type="success") => {
    setNotification({ msg, type });
    setTimeout(()=>setNotification(null), 2800);
  };

  const copyLink = (url) => {
    navigator.clipboard?.writeText(url).then(()=>showNotif("Link copied! ✓"));
    setSharePost(null);
  };

  // ── PULL TO REFRESH ────────────────────────────────────────
  const onTouchStart = (e) => { pullStartY.current = e.touches[0].clientY; };
  const onTouchEnd = (e) => { if(e.changedTouches[0].clientY-pullStartY.current>80&&tab==="home") handleRefresh(); };

  // ══════════════════════════════════════════════════════════
  // STYLES
  // ══════════════════════════════════════════════════════════
  const S = {
    app:{ fontFamily:"'Cormorant Garamond',Georgia,serif", background:C.bg, color:C.text, minHeight:"100vh", maxWidth:430, margin:"0 auto", position:"relative", display:"flex", flexDirection:"column", overflow:"hidden" },
    header:{ background:C.surface, borderBottom:`1px solid ${C.border}`, padding:"12px 16px 10px", display:"flex", alignItems:"center", justifyContent:"space-between", position:"sticky", top:0, zIndex:100 },
    logo:{ fontFamily:"'Playfair Display',serif", fontSize:21, fontWeight:700, color:C.gold, lineHeight:1 },
    logoSub:{ fontSize:8, color:C.textDim, letterSpacing:3, textTransform:"uppercase", marginTop:2 },
    offlineBanner:{ background:C.red, color:"#fff", textAlign:"center", fontSize:10, padding:"5px", letterSpacing:1, display:"flex", alignItems:"center", justifyContent:"center", gap:6 },
    ticker:{ background:C.gold, overflow:"hidden", padding:"5px 0", display:"flex", alignItems:"center" },
    tickerLabel:{ background:"#000", color:C.gold, fontSize:9, fontWeight:800, letterSpacing:2, padding:"2px 10px", whiteSpace:"nowrap", flexShrink:0 },
    tickerTrack:{ display:"flex", gap:40, animation:"ticker 30s linear infinite", paddingLeft:20 },
    tickerItem:{ fontSize:11, fontWeight:600, color:"#000", whiteSpace:"nowrap", cursor:"pointer" },
    catScroll:{ display:"flex", gap:8, overflowX:"auto", padding:"10px 16px", background:C.surface, borderBottom:`1px solid ${C.border}`, scrollbarWidth:"none" },
    catBtn:(a)=>({ padding:"6px 14px", borderRadius:20, border:`1px solid ${a?C.gold:C.border}`, background:a?C.gold:"transparent", color:a?"#000":C.textSec, fontSize:11, fontWeight:a?700:400, cursor:"pointer", whiteSpace:"nowrap", fontFamily:"inherit", letterSpacing:0.3, transition:"all 0.2s" }),
    scroll:{ flex:1, overflowY:"auto", paddingBottom:80, scrollbarWidth:"none" },
    heroCard:{ position:"relative", margin:"14px 14px 8px", borderRadius:18, overflow:"hidden", cursor:"pointer", boxShadow:`0 10px 50px rgba(0,0,0,0.5)` },
    heroImg:{ width:"100%", height:230, objectFit:"cover", display:"block" },
    heroOverlay:{ position:"absolute", inset:0, background:"linear-gradient(to top,rgba(0,0,0,0.95) 40%,rgba(0,0,0,0.1) 100%)" },
    heroContent:{ position:"absolute", bottom:0, left:0, right:0, padding:"16px" },
    heroBadge:{ display:"inline-flex", alignItems:"center", gap:4, background:C.gold, color:"#000", fontSize:9, fontWeight:800, letterSpacing:2, textTransform:"uppercase", padding:"3px 8px", borderRadius:4, marginBottom:8 },
    heroTitle:{ fontFamily:"'Playfair Display',serif", fontSize:19, fontWeight:700, color:"#fff", lineHeight:1.3, marginBottom:10 },
    heroMeta:{ display:"flex", alignItems:"center", gap:8 },
    heroTime:{ fontSize:11, color:"rgba(255,255,255,0.55)" },
    sLabel:{ fontSize:9, fontWeight:800, letterSpacing:3, textTransform:"uppercase", color:C.gold, padding:"16px 16px 8px", display:"flex", alignItems:"center", gap:8 },
    mrScroll:{ display:"flex", gap:12, overflowX:"auto", padding:"0 16px 12px", scrollbarWidth:"none" },
    mrCard:{ flexShrink:0, width:148, borderRadius:12, overflow:"hidden", cursor:"pointer", border:`1px solid ${C.border}` },
    mrImg:{ width:"100%", height:88, objectFit:"cover", display:"block" },
    mrBody:{ padding:"8px 10px 10px", background:C.card },
    mrCat:{ fontSize:8, color:C.gold, fontWeight:800, letterSpacing:1.5, textTransform:"uppercase", marginBottom:3 },
    mrTitle:{ fontFamily:"'Playfair Display',serif", fontSize:12, fontWeight:600, color:C.text, lineHeight:1.3, display:"-webkit-box", WebkitLineClamp:2, WebkitBoxOrient:"vertical", overflow:"hidden" },
    tagScroll:{ display:"flex", gap:8, overflowX:"auto", padding:"4px 16px 14px", scrollbarWidth:"none" },
    tagPill:(a)=>({ padding:"5px 12px", borderRadius:20, border:`1px solid ${a?C.gold:C.border}`, background:a?`${C.gold}22`:"transparent", color:a?C.gold:C.textDim, fontSize:11, cursor:"pointer", whiteSpace:"nowrap", fontFamily:"inherit" }),
    postCard:{ display:"flex", gap:12, padding:"13px 16px", borderBottom:`1px solid ${C.border}`, cursor:"pointer" },
    postThumb:{ width:86, height:70, borderRadius:10, objectFit:"cover", flexShrink:0, background:C.card },
    postPlaceholder:{ width:86, height:70, borderRadius:10, background:`linear-gradient(135deg,${C.card},${C.border})`, flexShrink:0, display:"flex", alignItems:"center", justifyContent:"center" },
    postInfo:{ flex:1, minWidth:0 },
    postCat:{ fontSize:8, fontWeight:800, letterSpacing:2, color:C.gold, textTransform:"uppercase", marginBottom:3 },
    postTitle:{ fontFamily:"'Playfair Display',serif", fontSize:14, fontWeight:600, color:C.text, lineHeight:1.35, marginBottom:6, display:"-webkit-box", WebkitLineClamp:2, WebkitBoxOrient:"vertical", overflow:"hidden" },
    postMeta:{ display:"flex", alignItems:"center", justifyContent:"space-between" },
    postMetaL:{ display:"flex", alignItems:"center", gap:8 },
    postTime:{ fontSize:10, color:C.textDim },
    postRT:{ fontSize:10, color:C.textDim, display:"flex", alignItems:"center", gap:3 },
    postActions:{ display:"flex", gap:8 },
    iBtn:{ background:"none", border:"none", cursor:"pointer", padding:3, display:"flex", alignItems:"center" },
    artOverlay:{ position:"fixed", inset:0, background:C.bg, zIndex:200, display:"flex", flexDirection:"column", maxWidth:430, margin:"0 auto", animation:"slideUp 0.3s cubic-bezier(0.16,1,0.3,1)" },
    artHeader:{ padding:"12px 14px", display:"flex", alignItems:"center", justifyContent:"space-between", borderBottom:`1px solid ${C.border}`, background:C.surface, position:"sticky", top:0, zIndex:10, overflow:"hidden" },
    progressBar:(p)=>({ position:"absolute", bottom:0, left:0, height:2, width:`${p}%`, background:C.gold, transition:"width 0.1s" }),
    artBody:{ flex:1, overflowY:"auto", scrollbarWidth:"none" },
    artHero:{ width:"100%", height:220, objectFit:"cover", display:"block" },
    artContent:{ padding:"18px 16px" },
    artCat:{ display:"inline-block", background:C.gold, color:"#000", fontSize:8, fontWeight:800, letterSpacing:2, textTransform:"uppercase", padding:"3px 8px", borderRadius:4, marginBottom:10 },
    artTitle:{ fontFamily:"'Playfair Display',serif", fontSize:22, fontWeight:700, color:C.text, lineHeight:1.3, marginBottom:14 },
    artMeta:{ display:"flex", alignItems:"center", justifyContent:"space-between", paddingBottom:14, borderBottom:`1px solid ${C.border}`, marginBottom:16 },
    artAuthorRow:{ display:"flex", alignItems:"center", gap:8, cursor:"pointer" },
    artAvatar:{ width:32, height:32, borderRadius:"50%", objectFit:"cover", background:C.card, display:"block" },
    artAuthorName:{ fontSize:12, fontWeight:600, color:C.textSec },
    artDate:{ fontSize:11, color:C.textDim },
    artRT:{ display:"flex", alignItems:"center", gap:4, fontSize:11, color:C.gold, background:`${C.gold}18`, padding:"3px 8px", borderRadius:10 },
    artExcerpt:{ fontSize:bodySize, lineHeight:1.8, color:C.textSec, marginBottom:20, fontStyle:"italic" },
    artCallout:{ padding:"14px", background:C.card, borderRadius:12, borderLeft:`3px solid ${C.gold}`, marginBottom:18 },
    readFullBtn:{ display:"flex", alignItems:"center", justifyContent:"center", gap:8, background:C.gold, color:"#000", padding:"14px 20px", borderRadius:12, fontSize:14, fontWeight:700, cursor:"pointer", border:"none", width:"100%", fontFamily:"inherit" },
    relCard:{ display:"flex", gap:10, padding:"10px 0", borderBottom:`1px solid ${C.border}`, cursor:"pointer" },
    relThumb:{ width:70, height:56, borderRadius:8, objectFit:"cover", background:C.card, flexShrink:0 },
    relTitle:{ fontFamily:"'Playfair Display',serif", fontSize:12, fontWeight:600, color:C.text, lineHeight:1.3, display:"-webkit-box", WebkitLineClamp:2, WebkitBoxOrient:"vertical", overflow:"hidden" },
    nav:{ position:"fixed", bottom:0, left:"50%", transform:"translateX(-50%)", width:"100%", maxWidth:430, background:C.surface, borderTop:`1px solid ${C.border}`, display:"flex", zIndex:150 },
    navBtn:(a)=>({ flex:1, padding:"9px 0 11px", display:"flex", flexDirection:"column", alignItems:"center", gap:3, background:"none", border:"none", cursor:"pointer", fontSize:8, fontWeight:700, letterSpacing:1, textTransform:"uppercase", color:a?C.gold:C.textDim, fontFamily:"inherit", transition:"color 0.2s" }),
    shareModal:{ position:"fixed", inset:0, background:"rgba(0,0,0,0.75)", zIndex:300, display:"flex", alignItems:"flex-end", justifyContent:"center" },
    shareSheet:{ background:C.surface, borderRadius:"22px 22px 0 0", padding:"20px 20px 40px", width:"100%", maxWidth:430, animation:"slideUp 0.25s cubic-bezier(0.16,1,0.3,1)" },
    shareHandle:{ width:36, height:4, background:C.border, borderRadius:2, margin:"0 auto 18px" },
    shareOptions:{ display:"flex", justifyContent:"space-around", marginBottom:16 },
    shareOpt:{ display:"flex", flexDirection:"column", alignItems:"center", gap:8, background:"none", border:"none", cursor:"pointer", color:C.textSec, fontSize:11, fontFamily:"inherit" },
    shareIcon:{ width:52, height:52, borderRadius:14, background:C.card, display:"flex", alignItems:"center", justifyContent:"center", border:`1px solid ${C.border}` },
    toast:(t)=>({ position:"fixed", bottom:88, left:"50%", transform:"translateX(-50%)", background:t==="error"?C.red:t==="warn"?"#B87020":C.gold, color:t==="error"?"#fff":"#000", padding:"10px 20px", borderRadius:24, fontSize:12, fontWeight:700, zIndex:999, whiteSpace:"nowrap", boxShadow:"0 4px 24px rgba(0,0,0,0.4)", animation:"fadeIn 0.2s ease" }),
    authorOverlay:{ position:"fixed", inset:0, background:C.bg, zIndex:250, display:"flex", flexDirection:"column", maxWidth:430, margin:"0 auto", animation:"slideUp 0.3s ease" },
    authorHero:{ background:`linear-gradient(135deg,${C.surface},${C.card})`, padding:"28px 20px 22px", textAlign:"center", borderBottom:`1px solid ${C.border}` },
    authorAvatar:{ width:72, height:72, borderRadius:"50%", objectFit:"cover", border:`3px solid ${C.gold}`, margin:"0 auto 10px", display:"block", background:C.card },
    settModal:{ position:"fixed", inset:0, background:"rgba(0,0,0,0.75)", zIndex:300, display:"flex", alignItems:"flex-end", justifyContent:"center" },
    settSheet:{ background:C.surface, borderRadius:"22px 22px 0 0", padding:"20px 20px 40px", width:"100%", maxWidth:430, animation:"slideUp 0.25s ease" },
    settRow:{ display:"flex", alignItems:"center", justifyContent:"space-between", padding:"13px 0", borderBottom:`1px solid ${C.border}` },
    fontBtns:{ display:"flex", gap:6 },
    fontBtn:(a)=>({ padding:"4px 10px", borderRadius:8, border:`1px solid ${a?C.gold:C.border}`, background:a?C.gold:"transparent", color:a?"#000":C.textSec, fontSize:11, cursor:"pointer", fontFamily:"inherit" }),
    toggle:(on)=>({ width:44, height:24, borderRadius:12, background:on?C.gold:C.border, position:"relative", cursor:"pointer", transition:"background 0.2s" }),
    toggleThumb:(on)=>({ position:"absolute", top:2, left:on?22:2, width:20, height:20, borderRadius:"50%", background:"#fff", transition:"left 0.2s" }),
    shimmer:{ background:`linear-gradient(90deg,${C.card} 25%,${C.border} 50%,${C.card} 75%)`, backgroundSize:"200% 100%", animation:"shimmer 1.5s infinite", borderRadius:8 },
    emptyState:{ textAlign:"center", padding:"48px 30px", color:C.textDim },
    refreshPill:{ position:"absolute", top:10, left:"50%", transform:"translateX(-50%)", background:C.gold, color:"#000", borderRadius:20, padding:"6px 14px", fontSize:11, fontWeight:700, display:"flex", alignItems:"center", gap:6, boxShadow:"0 4px 16px rgba(0,0,0,0.3)", zIndex:50, animation:"fadeIn 0.2s ease" },
  };

  // ── SUB-COMPONENTS ─────────────────────────────────────────
  const Skeleton = () => (
    <div style={{ padding:"13px 16px", borderBottom:`1px solid ${C.border}`, display:"flex", gap:12 }}>
      <div style={{ ...S.shimmer, width:86, height:70, borderRadius:10, flexShrink:0 }}/>
      <div style={{ flex:1 }}>
        <div style={{ ...S.shimmer, height:9, width:"35%", marginBottom:7 }}/>
        <div style={{ ...S.shimmer, height:13, width:"100%", marginBottom:5 }}/>
        <div style={{ ...S.shimmer, height:13, width:"75%", marginBottom:10 }}/>
        <div style={{ ...S.shimmer, height:9, width:"25%" }}/>
      </div>
    </div>
  );

  const PostCard = ({ post, onPress, compact=false }) => {
    const thumb = getThumb(post);
    const cat = getCategory(post);
    const title = stripHtml(post.title?.rendered||"");
    const bmed = isBM(post.id);
    const rt = readTime(post);
    return (
      <div style={S.postCard} onClick={onPress}>
        {thumb
          ? <img src={thumb} alt="" style={S.postThumb} loading="lazy"/>
          : <div style={S.postPlaceholder}><IC n="fire" size={22} color={C.goldDim}/></div>
        }
        <div style={S.postInfo}>
          {cat && <div style={S.postCat}>{cat}</div>}
          <div style={{ ...S.postTitle, fontSize:compact?13:14 }}>{title}</div>
          <div style={S.postMeta}>
            <div style={S.postMetaL}>
              <span style={S.postTime}>{timeAgo(post.date)}</span>
              <span style={S.postRT}><IC n="clock" size={10} color={C.textDim}/>{rt}m</span>
            </div>
            <div style={S.postActions}>
              <button style={S.iBtn} onClick={e=>{e.stopPropagation();setSharePost(post);}}><IC n="share" size={14} color={C.textDim}/></button>
              <button style={S.iBtn} onClick={e=>{e.stopPropagation();toggleBM(post);}}><IC n="bm" size={14} color={bmed?C.gold:C.textDim} fill={bmed?C.gold:"none"}/></button>
            </div>
          </div>
        </div>
      </div>
    );
  };

  const ArticleView = ({ post, onClose }) => {
    const [progress, setProgress] = useState(0);
    const thumb = getThumb(post);
    const cat = getCategory(post);
    const title = stripHtml(post.title?.rendered||"");
    const excerpt = stripHtml(post.excerpt?.rendered||"").slice(0,420);
    const author = getAuthor(post);
    const avatar = getAuthorAvatar(post);
    const bmed = isBM(post.id);
    const rt = readTime(post);
    const related = posts.filter(p=>p.id!==post.id&&getCategory(p)===cat).slice(0,3);
    const onScroll = (e) => {
      const { scrollTop, scrollHeight, clientHeight } = e.target;
      setProgress(Math.round((scrollTop/(scrollHeight-clientHeight||1))*100));
    };
    return (
      <div style={S.artOverlay}>
        <div style={{ ...S.artHeader, position:"relative" }}>
          <button style={S.iBtn} onClick={onClose}><IC n="back" size={22} color={C.text}/></button>
          <div style={{ fontFamily:"'Playfair Display',serif", fontSize:13, color:C.gold, fontWeight:600 }}>AllBioHub</div>
          <div style={{ display:"flex", gap:8 }}>
            <button style={S.iBtn} onClick={()=>setSharePost(post)}><IC n="share" size={19} color={C.textSec}/></button>
            <button style={S.iBtn} onClick={()=>toggleBM(post)}><IC n="bm" size={19} color={bmed?C.gold:C.textSec} fill={bmed?C.gold:"none"}/></button>
          </div>
          <div style={S.progressBar(progress)}/>
        </div>
        <div style={S.artBody} onScroll={onScroll}>
          {thumb && <img src={thumb} alt="" style={S.artHero}/>}
          <div style={S.artContent}>
            {cat && <div style={S.artCat}>{cat}</div>}
            <h1 style={S.artTitle}>{title}</h1>
            <div style={S.artMeta}>
              <div style={S.artAuthorRow} onClick={()=>{onClose();openAuthor(post);}}>
                {avatar
                  ? <img src={avatar} alt="" style={S.artAvatar}/>
                  : <div style={{...S.artAvatar,display:"flex",alignItems:"center",justifyContent:"center"}}><IC n="user" size={16} color={C.textDim}/></div>
                }
                <div>
                  <div style={S.artAuthorName}>{author}</div>
                  <div style={S.artDate}>{new Date(post.date).toLocaleDateString("en-US",{month:"long",day:"numeric",year:"numeric"})}</div>
                </div>
              </div>
              <div style={S.artRT}><IC n="clock" size={12} color={C.gold}/>{rt} min read</div>
            </div>
            <p style={S.artExcerpt}>{excerpt}{excerpt.length===420?"…":""}</p>
            <div style={S.artCallout}>
              <div style={{ fontSize:11, color:C.textDim, marginBottom:4 }}>📰 Full Article on AllBioHub.com</div>
              <div style={{ fontSize:13, color:C.textSec }}>Complete story with photos, quotes, and more awaits you on the website.</div>
            </div>
            <button style={S.readFullBtn} onClick={()=>window.open(post.link,"_blank")}>
              Read Full Article <IC n="ext" size={16} color="#000"/>
            </button>
            {related.length>0 && (
              <div style={{ marginTop:28 }}>
                <div style={{ ...S.sLabel, padding:"0 0 10px", fontSize:9 }}><IC n="trending" size={13} color={C.gold}/>Related Stories</div>
                {related.map(rp=>(
                  <div key={rp.id} style={S.relCard} onClick={()=>openPost(rp)}>
                    {getThumb(rp)
                      ? <img src={getThumb(rp)} alt="" style={S.relThumb} loading="lazy"/>
                      : <div style={{...S.relThumb,display:"flex",alignItems:"center",justifyContent:"center"}}><IC n="fire" size={16} color={C.goldDim}/></div>
                    }
                    <div style={{ flex:1 }}>
                      <div style={{ fontSize:8, color:C.gold, fontWeight:800, letterSpacing:2, textTransform:"uppercase", marginBottom:3 }}>{getCategory(rp)}</div>
                      <div style={S.relTitle}>{stripHtml(rp.title?.rendered||"")}</div>
                      <div style={{ fontSize:10, color:C.textDim, marginTop:4 }}>{timeAgo(rp.date)}</div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    );
  };

  const AuthorPage = ({ post, onClose }) => {
    const author = getAuthor(post);
    const avatar = getAuthorAvatar(post);
    return (
      <div style={S.authorOverlay}>
        <div style={S.artHeader}>
          <button style={S.iBtn} onClick={onClose}><IC n="back" size={22} color={C.text}/></button>
          <div style={{ fontFamily:"'Playfair Display',serif", fontSize:13, color:C.gold, fontWeight:600 }}>Author Profile</div>
          <div style={{ width:22 }}/>
        </div>
        <div style={{ ...S.scroll }}>
          <div style={S.authorHero}>
            {avatar
              ? <img src={avatar} alt="" style={S.authorAvatar}/>
              : <div style={{...S.authorAvatar,display:"flex",alignItems:"center",justifyContent:"center"}}><IC n="user" size={28} color={C.textDim}/></div>
            }
            <div style={{ fontFamily:"'Playfair Display',serif", fontSize:22, fontWeight:700, color:C.text }}>{author}</div>
            <div style={{ fontSize:12, color:C.textDim, marginTop:4 }}>AllBioHub Contributor</div>
          </div>
          <div style={S.sLabel}><IC n="text" size={13} color={C.gold}/>Articles by {author}</div>
          {authorLoading
            ? Array(4).fill(0).map((_,i)=><Skeleton key={i}/>)
            : (authorPosts.length>0?authorPosts:posts.slice(0,6)).map(p=><PostCard key={p.id} post={p} onPress={()=>openPost(p)}/>)
          }
        </div>
      </div>
    );
  };

  const ShareSheet = ({ post, onClose }) => {
    const url = post?.link||"";
    const title = stripHtml(post?.title?.rendered||"");
    const opts = [
      { icon:"x", label:"X / Twitter", action:()=>{window.open(`https://twitter.com/intent/tweet?text=${encodeURIComponent(title)}&url=${encodeURIComponent(url)}`);onClose();}},
      { icon:"wa", label:"WhatsApp", action:()=>{window.open(`https://wa.me/?text=${encodeURIComponent(title+" "+url)}`);onClose();}},
      { icon:"fb", label:"Facebook", action:()=>{window.open(`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`);onClose();}},
      { icon:"copy", label:"Copy Link", action:()=>copyLink(url)},
    ];
    return (
      <div style={S.shareModal} onClick={onClose}>
        <div style={S.shareSheet} onClick={e=>e.stopPropagation()}>
          <div style={S.shareHandle}/>
          <div style={{ fontSize:15, fontWeight:700, color:C.text, textAlign:"center", marginBottom:8 }}>Share Article</div>
          <div style={{ fontSize:12, color:C.textSec, textAlign:"center", marginBottom:18, padding:"0 16px", lineHeight:1.5 }}>{title.slice(0,70)}…</div>
          <div style={S.shareOptions}>
            {opts.map(o=>(
              <button key={o.label} style={S.shareOpt} onClick={o.action}>
                <div style={S.shareIcon}><IC n={o.icon} size={22} color={C.gold}/></div>
                <span>{o.label}</span>
              </button>
            ))}
          </div>
          <button style={{ ...S.readFullBtn, marginTop:12, background:C.card, color:C.textSec }} onClick={onClose}>Cancel</button>
        </div>
      </div>
    );
  };

  const SettingsSheet = ({ onClose }) => (
    <div style={S.settModal} onClick={onClose}>
      <div style={S.settSheet} onClick={e=>e.stopPropagation()}>
        <div style={S.shareHandle}/>
        <div style={{ fontSize:16, fontWeight:700, color:C.text, marginBottom:4 }}>Reading Preferences</div>
        <div style={S.settRow}>
          <span style={{ fontSize:14, color:C.text }}>Font Size</span>
          <div style={S.fontBtns}>
            {["small","medium","large"].map(f=>(
              <button key={f} style={S.fontBtn(fontSize===f)} onClick={()=>setFontSize(f)}>{f.charAt(0).toUpperCase()+f.slice(1)}</button>
            ))}
          </div>
        </div>
        <div style={S.settRow}>
          <span style={{ fontSize:14, color:C.text }}>Dark Mode</span>
          <div style={S.toggle(dark)} onClick={()=>setDark(d=>!d)}><div style={S.toggleThumb(dark)}/></div>
        </div>
        <div style={S.settRow}>
          <span style={{ fontSize:14, color:C.text }}>Push Notifications</span>
          <div style={S.toggle(notifEnabled)} onClick={()=>{setNotifEnabled(n=>!n);showNotif(notifEnabled?"Notifications off":"Notifications on ✓");}}>
            <div style={S.toggleThumb(notifEnabled)}/>
          </div>
        </div>
        <div style={S.settRow}>
          <span style={{ fontSize:14, color:C.text }}>Network Status</span>
          <span style={{ fontSize:12, color:isOffline?C.red:C.green, display:"flex", alignItems:"center", gap:5 }}>
            <IC n="wifi" size={13} color={isOffline?C.red:C.green}/>{isOffline?"Offline":"Online"}
          </span>
        </div>
        <button style={{ ...S.readFullBtn, marginTop:18, background:C.card, color:C.textSec }} onClick={onClose}>Done</button>
      </div>
    </div>
  );

  // ── TABS ───────────────────────────────────────────────────
  const HomeTab = () => (
    <div style={{ ...S.scroll, position:"relative" }}
      onTouchStart={onTouchStart} onTouchEnd={onTouchEnd}
      onScroll={e=>{ const {scrollTop,scrollHeight,clientHeight}=e.target; if(scrollHeight-scrollTop-clientHeight<300) loadMore(); }}>
      {refreshing && <div style={S.refreshPill}><IC n="refresh" size={13} color="#000"/>Refreshing…</div>}

      {/* Hero */}
      {featuredPost && !loading && (
        <div style={S.heroCard} onClick={()=>openPost(featuredPost)}>
          {getThumb(featuredPost)
            ? <img src={getThumb(featuredPost)} alt="" style={S.heroImg}/>
            : <div style={{...S.heroImg,background:`linear-gradient(135deg,${C.card},${C.border})`,display:"flex",alignItems:"center",justifyContent:"center"}}><IC n="fire" size={44} color={C.goldDim}/></div>
          }
          <div style={S.heroOverlay}/>
          <div style={S.heroContent}>
            <div style={S.heroBadge}><IC n="fire" size={10} color="#000"/>Featured</div>
            <div style={S.heroTitle}>{stripHtml(featuredPost.title?.rendered||"").slice(0,80)}</div>
            <div style={S.heroMeta}>
              <span style={S.heroTime}>{timeAgo(featuredPost.date)}</span>
              <span style={{...S.heroTime,marginLeft:8}}>· {readTime(featuredPost)} min read</span>
            </div>
          </div>
        </div>
      )}

      {/* Breaking Ticker */}
      {!loading && posts.length>0 && (
        <div style={S.ticker}>
          <div style={S.tickerLabel}>BREAKING</div>
          <div style={{ overflow:"hidden", flex:1 }}>
            <div style={S.tickerTrack}>
              {[...posts.slice(0,5),...posts.slice(0,5)].map((p,i)=>(
                <span key={i} style={S.tickerItem} onClick={()=>openPost(p)}>{stripHtml(p.title?.rendered||"").slice(0,55)}</span>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Most Read */}
      {mostRead.length>0 && !loading && (
        <>
          <div style={S.sLabel}><IC n="trending" size={13} color={C.gold}/>Most Read Today</div>
          <div style={S.mrScroll}>
            {mostRead.map(p=>(
              <div key={p.id} style={S.mrCard} onClick={()=>openPost(p)}>
                {getThumb(p)
                  ? <img src={getThumb(p)} alt="" style={S.mrImg} loading="lazy"/>
                  : <div style={{...S.mrImg,background:`linear-gradient(135deg,${C.card},${C.border})`,display:"flex",alignItems:"center",justifyContent:"center"}}><IC n="fire" size={18} color={C.goldDim}/></div>
                }
                <div style={S.mrBody}>
                  <div style={S.mrCat}>{getCategory(p)||"News"}</div>
                  <div style={S.mrTitle}>{stripHtml(p.title?.rendered||"")}</div>
                </div>
              </div>
            ))}
          </div>
        </>
      )}

      {/* Trending Tags */}
      <div style={S.sLabel}><IC n="tag" size={13} color={C.gold}/>Trending Topics</div>
      <div style={S.tagScroll}>
        {TRENDING_TAGS.map(tag=>(
          <button key={tag} style={S.tagPill(activeTag===tag)} onClick={()=>handleTag(tag)}>{tag}</button>
        ))}
      </div>

      {/* Feed */}
      <div style={S.sLabel}><IC n="fire" size={13} color={C.gold}/>Latest Stories · {total}</div>
      {loading
        ? Array(6).fill(0).map((_,i)=><Skeleton key={i}/>)
        : posts.slice(featuredPost?1:0).map(p=><PostCard key={p.id} post={p} onPress={()=>openPost(p)}/>)
      }
      {loadingMore && <div style={{textAlign:"center",padding:20,color:C.textDim,fontSize:12}}>Loading more…</div>}
      {!loading&&!hasMore&&posts.length>0 && <div style={{textAlign:"center",padding:"20px",color:C.textDim,fontSize:11,letterSpacing:1}}>— You're all caught up —</div>}
    </div>
  );

  const SearchTab = () => (
    <div style={S.scroll}>
      <div style={{ padding:"14px 16px" }}>
        <input style={{ width:"100%", padding:"11px 14px", background:C.card, border:`1px solid ${C.border}`, borderRadius:12, color:C.text, fontSize:14, outline:"none", fontFamily:"inherit" }}
          placeholder="Search biographies, news, people…" value={searchQuery} onChange={e=>setSearchQuery(e.target.value)} autoFocus/>
      </div>
      {!searchQuery && (
        <>
          <div style={S.sLabel}><IC n="tag" size={13} color={C.gold}/>Browse by Topic</div>
          <div style={{ display:"flex", flexWrap:"wrap", gap:8, padding:"0 16px 16px" }}>
            {TRENDING_TAGS.map(tag=><button key={tag} style={S.tagPill(false)} onClick={()=>handleTag(tag)}>{tag}</button>)}
          </div>
          {readHistory.length>0 && (
            <>
              <div style={S.sLabel}><IC n="clock" size={13} color={C.gold}/>Continue Reading</div>
              {readHistory.slice(0,3).map(p=><PostCard key={p.id} post={p} onPress={()=>openPost(p)} compact/>)}
            </>
          )}
          <div style={S.emptyState}>
            <IC n="search" size={36} color={C.border}/>
            <div style={{ marginTop:14, fontSize:16, color:C.textDim, fontFamily:"'Playfair Display',serif" }}>Search AllBioHub</div>
            <div style={{ marginTop:6, fontSize:12, color:C.textDim }}>Biographies · Celebrity News · Trends</div>
          </div>
        </>
      )}
      {searching && <div style={{textAlign:"center",padding:28,color:C.textDim,fontSize:13}}>Searching…</div>}
      {!searching&&searchQuery&&searchResults.length===0 && <div style={S.emptyState}><div style={{fontSize:15,color:C.textDim}}>No results for "{searchQuery}"</div></div>}
      {searchResults.map(p=><PostCard key={p.id} post={p} onPress={()=>openPost(p)}/>)}
    </div>
  );

  const BookmarksTab = () => (
    <div style={S.scroll}>
      <div style={S.sLabel}><IC n="bm" size={13} color={C.gold} fill={C.gold}/>Saved Articles · {bookmarks.length}</div>
      {bookmarks.length===0
        ? <div style={S.emptyState}>
            <IC n="bm" size={38} color={C.border}/>
            <div style={{marginTop:14,fontSize:16,color:C.textDim,fontFamily:"'Playfair Display',serif"}}>No bookmarks yet</div>
            <div style={{marginTop:6,fontSize:12,color:C.textDim}}>Tap 🔖 on any article to save it here</div>
          </div>
        : bookmarks.map(p=><PostCard key={p.id} post={p} onPress={()=>openPost(p)}/>)
      }
      {readHistory.length>0 && (
        <>
          <div style={{...S.sLabel,marginTop:8}}><IC n="clock" size={13} color={C.gold}/>Recently Read</div>
          {readHistory.map(p=><PostCard key={p.id} post={p} onPress={()=>openPost(p)} compact/>)}
        </>
      )}
    </div>
  );

  const AboutTab = () => (
    <div style={S.scroll}>
      <div style={{background:`linear-gradient(135deg,${C.surface},${C.card})`,padding:"36px 24px 28px",textAlign:"center",borderBottom:`1px solid ${C.border}`}}>
        <div style={{fontFamily:"'Playfair Display',serif",fontSize:34,fontWeight:700,color:C.gold}}>AllBioHub</div>
        <div style={{fontSize:9,color:C.goldDim,letterSpacing:4,textTransform:"uppercase",marginTop:3}}>Media · Stories · People</div>
        <div style={{marginTop:14,fontSize:13,color:C.textSec,lineHeight:1.7,maxWidth:280,margin:"14px auto 0"}}>Your premier destination for in-depth celebrity biographies, entertainment news, and inspiring stories.</div>
        <div style={{display:"flex",justifyContent:"space-around",marginTop:22}}>
          {[{n:"500+",l:"Biographies"},{n:"10K+",l:"Readers"},{n:"7",l:"Categories"}].map(s=>(
            <div key={s.l} style={{textAlign:"center"}}>
              <div style={{fontFamily:"'Playfair Display',serif",fontSize:26,fontWeight:700,color:C.gold}}>{s.n}</div>
              <div style={{fontSize:10,color:C.textDim,letterSpacing:1}}>{s.l}</div>
            </div>
          ))}
        </div>
      </div>

      <div style={{padding:"16px"}}>
        <div style={{fontSize:9,fontWeight:800,letterSpacing:3,textTransform:"uppercase",color:C.gold,marginBottom:10}}>App Settings</div>
        <div style={S.settRow}>
          <span style={{fontSize:14,color:C.text}}>Font Size</span>
          <div style={S.fontBtns}>
            {["small","medium","large"].map(f=>(
              <button key={f} style={S.fontBtn(fontSize===f)} onClick={()=>setFontSize(f)}>{f.charAt(0).toUpperCase()+f.slice(1)}</button>
            ))}
          </div>
        </div>
        <div style={S.settRow}>
          <span style={{fontSize:14,color:C.text}}>Dark Mode</span>
          <div style={S.toggle(dark)} onClick={()=>setDark(d=>!d)}><div style={S.toggleThumb(dark)}/></div>
        </div>
        <div style={S.settRow}>
          <span style={{fontSize:14,color:C.text}}>Notifications</span>
          <div style={S.toggle(notifEnabled)} onClick={()=>{setNotifEnabled(n=>!n);showNotif(notifEnabled?"Notifications off":"Notifications on ✓");}}><div style={S.toggleThumb(notifEnabled)}/></div>
        </div>
        <div style={S.settRow}>
          <span style={{fontSize:14,color:C.text}}>Network</span>
          <span style={{fontSize:12,color:isOffline?C.red:C.green,display:"flex",alignItems:"center",gap:5}}><IC n="wifi" size={13} color={isOffline?C.red:C.green}/>{isOffline?"Offline — Cached":"Online"}</span>
        </div>
      </div>

      <div style={{padding:"0 16px"}}>
        <div style={{fontSize:9,fontWeight:800,letterSpacing:3,textTransform:"uppercase",color:C.gold,marginBottom:10}}>What We Cover</div>
        {["📖 In-depth celebrity biographies","⭐ Celebrity news & gossip","💡 Startup founders & innovators","💰 Money & career insights","🌐 Around the web","🔍 Product reviews"].map(item=>(
          <div key={item} style={{padding:"9px 0",fontSize:13,color:C.textSec,borderBottom:`1px solid ${C.border}`}}>{item}</div>
        ))}
      </div>

      <div style={{padding:"16px 16px"}}>
        <div style={{fontSize:9,fontWeight:800,letterSpacing:3,textTransform:"uppercase",color:C.gold,marginBottom:10,marginTop:8}}>Links</div>
        {[
          {l:"🌐 Visit Website",u:"https://allbiohub.com"},
          {l:"✉️ Contact Us",u:"https://allbiohub.com/contact-us/"},
          {l:"📢 Advertise",u:"https://allbiohub.com/advertise-with-us/"},
          {l:"✍️ Write & Earn",u:"https://allbiohub.com/write-earn-on-allbiohub/"},
          {l:"🛡️ Privacy Policy",u:"https://allbiohub.com/privacy-policy/"},
        ].map(link=>(
          <button key={link.l} onClick={()=>window.open(link.u,"_blank")} style={{display:"flex",justifyContent:"space-between",alignItems:"center",width:"100%",background:"none",border:"none",borderBottom:`1px solid ${C.border}`,padding:"12px 0",cursor:"pointer",color:C.text,fontSize:13,fontFamily:"inherit"}}>
            {link.l}<IC n="ext" size={13} color={C.textDim}/>
          </button>
        ))}
      </div>

      <div style={{textAlign:"center",padding:"16px 20px 30px",color:C.textDim,fontSize:10,letterSpacing:1}}>
        © 2026 AllBioHub Media · BlissNova Publishing Group<br/>
        <span style={{color:C.goldDim}}>Reg. No 8625480</span>
      </div>
    </div>
  );

  // ── RENDER ─────────────────────────────────────────────────
  return (
    <>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;600;700&family=Cormorant+Garamond:ital,wght@0,400;0,600;1,400&display=swap');
        *{box-sizing:border-box;margin:0;padding:0;-webkit-tap-highlight-color:transparent;}
        ::-webkit-scrollbar{display:none;}
        @keyframes slideUp{from{transform:translateY(40px);opacity:0}to{transform:translateY(0);opacity:1}}
        @keyframes fadeIn{from{opacity:0;transform:translateX(-50%) translateY(6px)}to{opacity:1;transform:translateX(-50%) translateY(0)}}
        @keyframes shimmer{0%{background-position:-200% 0}100%{background-position:200% 0}}
        @keyframes ticker{0%{transform:translateX(0)}100%{transform:translateX(-50%)}}
        input::placeholder{color:${C.textDim};}
      `}</style>

      <div style={S.app}>
        {isOffline && <div style={S.offlineBanner}><IC n="wifi" size={11} color="#fff"/>OFFLINE — SHOWING CACHED CONTENT</div>}

        {/* Header */}
        <div style={S.header}>
          <div>
            <div style={S.logo}>AllBioHub</div>
            <div style={S.logoSub}>Media · Stories</div>
          </div>
          <div style={{display:"flex",gap:8,alignItems:"center"}}>
            <button style={S.iBtn} onClick={()=>showNotif(notifEnabled?"🔔 You're subscribed!":"Enable notifications first")}><IC n="bell" size={20} color={notifEnabled?C.gold:C.textDim}/></button>
            <button style={S.iBtn} onClick={()=>setShowSettings(true)}><IC n="text" size={20} color={C.textSec}/></button>
            <button onClick={()=>setDark(d=>!d)} style={{background:"none",border:`1px solid ${C.border}`,borderRadius:20,padding:"5px 10px",cursor:"pointer",display:"flex",alignItems:"center",gap:5,fontSize:10,color:C.textSec,fontFamily:"inherit"}}>
              <IC n={dark?"sun":"moon"} size={13} color={C.textSec}/>{dark?"Light":"Dark"}
            </button>
          </div>
        </div>

        {/* Category Tabs */}
        {tab==="home" && (
          <div style={S.catScroll}>
            {CATEGORIES.map(c=>(
              <button key={c.id} style={S.catBtn(activeCat===c.id)} onClick={()=>{setActiveCat(c.id);setPage(1);}}>{c.label}</button>
            ))}
          </div>
        )}

        {tab==="home" && <HomeTab/>}
        {tab==="search" && <SearchTab/>}
        {tab==="bookmarks" && <BookmarksTab/>}
        {tab==="about" && <AboutTab/>}

        {/* Bottom Nav */}
        <nav style={S.nav}>
          {[
            {id:"home",icon:"home",label:"Home"},
            {id:"search",icon:"search",label:"Search"},
            {id:"bookmarks",icon:"bm",label:`Saved${bookmarks.length>0?` (${bookmarks.length})`:""}`},
            {id:"about",icon:"info",label:"About"},
          ].map(n=>(
            <button key={n.id} style={S.navBtn(tab===n.id)} onClick={()=>setTab(n.id)}>
              <IC n={n.icon} size={21} color={tab===n.id?C.gold:C.textDim} fill={n.id==="bookmarks"&&bookmarks.length>0&&tab===n.id?C.gold:"none"}/>
              {n.label}
            </button>
          ))}
        </nav>

        {/* Overlays */}
        {selectedPost && <ArticleView post={selectedPost} onClose={()=>setSelectedPost(null)}/>}
        {authorPost && <AuthorPage post={authorPost} onClose={()=>setAuthorPost(null)}/>}
        {sharePost && <ShareSheet post={sharePost} onClose={()=>setSharePost(null)}/>}
        {showSettings && <SettingsSheet onClose={()=>setShowSettings(false)}/>}
        {notification && <div style={S.toast(notification.type)}>{notification.msg}</div>}
      </div>
    </>
  );
}