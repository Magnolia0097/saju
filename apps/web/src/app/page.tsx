import { SITE } from '@/lib/site';

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center gap-6 px-6 text-center">
      <h1 className="text-3xl font-bold tracking-tight">{SITE.name}</h1>
      <p className="text-base leading-relaxed text-neutral-600">{SITE.description}</p>
      <button
        type="button"
        disabled
        className="w-full rounded-2xl bg-neutral-900 px-6 py-4 text-lg font-semibold text-white disabled:opacity-40"
      >
        내 사주 무료로 확인하기 (준비 중)
      </button>
    </main>
  );
}
