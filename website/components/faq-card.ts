/* A question card, shared with /faq so the two lists can't drift. Layered,
   transparent shadows give depth on any surface and lift a touch on open; the
   hairline keeps closed cards legible on the zinc-100 page. */
export const FAQ_CARD =
  "relative overflow-hidden rounded-2xl border border-border bg-card shadow-[0_1px_2px_rgba(0,0,0,0.03),0_4px_12px_-6px_rgba(0,0,0,0.06)] transition-[border-color,box-shadow] duration-300 data-[state=open]:border-zinc-300 data-[state=open]:shadow-[0_1px_2px_rgba(0,0,0,0.04),0_12px_28px_-12px_rgba(0,0,0,0.14)] dark:data-[state=open]:border-zinc-700 before:absolute before:bottom-0 before:left-0 before:top-0 before:w-1 before:bg-emerald-400 before:opacity-0 before:transition-opacity data-[state=open]:before:opacity-100";
export const FAQ_TRIGGER =
  "px-6 py-5 text-left text-[15px] font-semibold text-balance text-foreground hover:no-underline [&>svg]:text-muted-foreground";
export const FAQ_ANSWER = "px-6 pb-6 text-[15px] leading-relaxed text-pretty text-muted-foreground";
