defmodule HaAuth.Web.PairController do
  @moduledoc """
  The phone's side of the QR sign-in: `/pair/<code>` (behind sign-in) asks
  to approve the screen showing that code; the POST hands the phone's user
  to it.
  """
  use Phoenix.Controller, formats: [:html]

  alias HaAuth.Pairings

  plug :put_view, html: HaAuth.Web.PairHTML

  def show(conn, %{"code" => code}) do
    render(conn, :show,
      page_title: "Approve screen",
      code: code,
      pending: Pairings.pending?(code)
    )
  end

  def approve(conn, %{"code" => code}) do
    ok = Pairings.approve(code, conn.assigns.current_user) == :ok
    render(conn, :done, page_title: "Approve screen", ok: ok)
  end
end
