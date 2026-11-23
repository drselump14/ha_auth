defmodule HaAuth.Web.Components do
  @moduledoc false
  # Self-styled (inline CSS), so apps need no Tailwind setup for these pages.
  use Phoenix.Component

  slot :inner_block, required: true

  def page(assigns) do
    ~H"""
    <style>
      .ha-auth { min-height: 100dvh; display: grid; place-items: center; padding: 24px 16px;
        background: #000; color: #e4e4e7; font-family: system-ui, -apple-system, sans-serif;
        text-align: center; box-sizing: border-box; }
      .ha-auth * { box-sizing: border-box; }
      .ha-auth-box { width: 100%; max-width: 360px; }
      .ha-auth h1 { margin: 0; font-size: 32px; font-weight: 300; color: #fafafa; }
      .ha-auth p { margin: 12px 0 0; font-size: 15px; line-height: 1.4; color: #a1a1aa; }
      .ha-auth .ha-auth-error { color: #fca5a5; }
      .ha-auth-qr { margin: 24px auto 0; width: fit-content; padding: 12px; background: #fff;
        border-radius: 14px; line-height: 0; }
      .ha-auth-btn { display: block; width: 100%; margin-top: 24px; padding: 14px 20px;
        border: 0; border-radius: 999px; background: #27272a; color: #fafafa; font: inherit;
        font-size: 16px; font-weight: 500; text-decoration: none; cursor: pointer; }
      .ha-auth-btn.primary { background: #fafafa; color: #000; font-size: 18px; }
    </style>
    <main class="ha-auth">
      <div class="ha-auth-box">{render_slot(@inner_block)}</div>
    </main>
    """
  end
end
