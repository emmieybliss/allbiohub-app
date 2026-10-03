import { test } from "node:test";
import assert from "node:assert/strict";
import {
  cleanText, cleanUrl, containsBlockedTerm, countLinks, isEmail, mentions, normalizeUsername, placeReply, slugify,
  usernameProblem,
} from "../../src/validation.js";
import { plain } from "../../src/alerts.js";
import { wants } from "../../src/notifications.js";

test("usernames are normalized to lowercase without @", () => {
  assert.equal(normalizeUsername("  @EmmieYBliss "), "emmieybliss");
});

test("valid usernames pass", () => {
  for (const name of ["emmieybliss", "techlover", "startup_guy", "abc", "a1234567890123456789"]) {
    assert.equal(usernameProblem(name), null, name);
  }
});

test("username length, characters and shape are checked", () => {
  assert.equal(usernameProblem("ab"), "too_short");
  assert.equal(usernameProblem("a".repeat(21)), "too_long");
  assert.equal(usernameProblem("tech-lover"), "invalid_characters");
  assert.equal(usernameProblem("tech lover"), "invalid_characters");
  assert.equal(usernameProblem("émile"), "invalid_characters");
  assert.equal(usernameProblem("1tech"), "must_start_with_letter");
  assert.equal(usernameProblem("_tech"), "must_start_with_letter");
  assert.equal(usernameProblem("tech__lover"), "double_underscore");
});

test("reserved and abusive usernames are refused", () => {
  assert.equal(usernameProblem("admin"), "reserved");
  assert.equal(usernameProblem("allbiohub"), "reserved");
  assert.equal(usernameProblem("all_bio_hub"), "reserved");
  assert.equal(usernameProblem("support"), "reserved");
  assert.equal(usernameProblem("fuckface"), "not_allowed");
  assert.equal(usernameProblem("sh1tposter"), "not_allowed");
  assert.equal(usernameProblem("p0rn_star"), "not_allowed");
  assert.equal(usernameProblem("goodname", ["goodn"]), "not_allowed");
});

test("common real names are not blocked", () => {
  for (const name of ["dickson", "essex_fan", "cassandra", "hancock"]) {
    assert.notEqual(usernameProblem(name), "not_allowed", name);
  }
});

test("text is cleaned of control characters and extra blank lines", () => {
  assert.equal(cleanText("  hello\u0000 ‮world  "), "hello world");
  assert.equal(cleanText("a\r\n\r\n\r\n\r\nb", true), "a\n\nb");
  assert.equal(cleanText("a\n b", false), "a b");
});

test("links are counted", () => {
  assert.equal(countLinks("see https://a.com and www.b.org, not c.com"), 2);
  assert.equal(countLinks("no links"), 0);
});

test("urls are accepted only for http(s) with a real host", () => {
  assert.equal(cleanUrl("allbiohub.com"), "https://allbiohub.com/");
  assert.equal(cleanUrl("javascript:alert(1)"), null);
  assert.equal(cleanUrl("http://localhost"), null);
  assert.equal(cleanUrl(""), null);
});

test("emails", () => {
  assert.ok(isEmail("a@b.co"));
  assert.ok(!isEmail("a@b"));
  assert.ok(!isEmail("not an email"));
});

test("blocked terms match whole words only", () => {
  assert.ok(containsBlockedTerm("Buy cheap pills now", ["cheap pills"]));
  assert.ok(!containsBlockedTerm("Scunthorpe", ["cunt"]));
});

test("slugs", () => {
  assert.equal(slugify("Tosin Eniolorunda"), "tosin-eniolorunda");
  assert.equal(slugify("  Olúgbénga  Agboola! "), "olugbenga-agboola");
});

test("startup mentions are whole-word and case-insensitive", () => {
  assert.ok(mentions("Moniepoint raises $110m", "Moniepoint"));
  assert.ok(mentions("Why moniepoint matters", "Moniepoint"));
  assert.ok(!mentions("Moniepointers unite", "Moniepoint"));
  assert.ok(mentions("Paystack’s new product", "Paystack"));
  assert.ok(!mentions("an ai startup", "AI"));
});

test("replies nest at most two levels", () => {
  const top = { id: "c1", depth: 0, parentId: null, rootId: null };
  assert.deepEqual(placeReply(top), { parentId: "c1", rootId: "c1", depth: 1 });
  const reply = { id: "c2", depth: 1, parentId: "c1", rootId: "c1" };
  assert.deepEqual(placeReply(reply), { parentId: "c2", rootId: "c1", depth: 2 });
  const deepest = { id: "c3", depth: 2, parentId: "c2", rootId: "c1" };
  assert.deepEqual(placeReply(deepest), { parentId: "c2", rootId: "c1", depth: 2 });
});

test("html titles become plain text", () => {
  assert.equal(plain("<p>Moniepoint&#8217;s <b>big</b> &amp; bold</p>"), "Moniepoint's big & bold");
});

test("notification preferences default on except marketing", () => {
  assert.equal(wants(undefined, "commentActivity"), true);
  assert.equal(wants(undefined, "marketing"), false);
  assert.equal(wants({ commentActivity: false }, "commentActivity"), false);
});
