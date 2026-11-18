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
};

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
        return !saved;
      },
      remove: (id) => set({ items: get().items.filter((a) => a.id !== id) }),
      restore: (article, index) => {
        const items = get().items.filter((a) => a.id !== article.id);
        items.splice(Math.max(0, Math.min(index, items.length)), 0, strip(article));
        set({ items });
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
