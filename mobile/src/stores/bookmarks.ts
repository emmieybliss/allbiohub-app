import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import type { Article } from '@/models/types';

/** Saved stories, newest first. Content is left out to keep storage small. */
type BookmarksState = {
  items: Article[];
  isSaved: (id: number) => boolean;
  toggle: (article: Article) => boolean;
  remove: (id: number) => void;
  restore: (article: Article, index: number) => void;
  /** Adds a story saved to the account on another phone. */
  addFromAccount: (article: Article) => void;
};

/** Copies a change to the signed-in account; set by the community saved-items sync. */
let mirror: ((article: Article, saved: boolean) => void) | null = null;

export function setBookmarkMirror(fn: typeof mirror) {
  mirror = fn;
}

function strip(a: Article): Article {
  const { contentHtml: _content, ...rest } = a;
  return rest;
}

export const useBookmarks = create<BookmarksState>()(
  persist(
    (set, get) => ({
      items: [],
      isSaved: (id) => get().items.some((a) => a.id === id),
      toggle: (article) => {
        const saved = get().isSaved(article.id);
        set({ items: saved ? get().items.filter((a) => a.id !== article.id) : [strip(article), ...get().items] });
        mirror?.(article, !saved);
        return !saved;
      },
      remove: (id) => {
        const article = get().items.find((a) => a.id === id);
        set({ items: get().items.filter((a) => a.id !== id) });
        if (article) mirror?.(article, false);
      },
      restore: (article, index) => {
        const items = get().items.filter((a) => a.id !== article.id);
        items.splice(Math.max(0, Math.min(index, items.length)), 0, strip(article));
        set({ items });
        mirror?.(article, true);
      },
      addFromAccount: (article) => {
        if (get().isSaved(article.id)) return;
        set({ items: [...get().items, strip(article)] });
      },
    }),
    {
      name: 'abh.bookmarks',
      version: 1,
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (s) => ({ items: s.items }),
    },
  ),
);
