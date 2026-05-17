defmodule Bonfire.UI.Social.Feeds.FeedBrowserJSTimeLimitTest do
  use Bonfire.UI.Social.ConnCase, async: false
  @moduletag :ui
  @moduletag :browser_js
  @moduletag db_sandbox: false

  use Bonfire.Common.Config

  import Bonfire.Posts.Fake, except: [fake_remote_user!: 0]

  alias Bonfire.Common.DatesTimes

  @playwright_timeout 120_000

  setup do
    original_deferred = Config.get([Bonfire.Social.Feeds, :query_with_deferred_join])
    original_default_limit = Config.get(:default_pagination_limit)

    Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], false)
    Config.put(:default_pagination_limit, 2)
    Bonfire.Common.Cache.remove_all()

    account = fake_account!()
    _viewer = fake_user!(account)
    author = fake_user!()

    repo().delete_all(Bonfire.Data.Social.FeedPublish)

    dated_post!(author, "browser recent post", "Browser recent", DatesTimes.past(1, :hour))
    dated_post!(author, "browser two days", "Browser two days", DatesTimes.past(2, :day))
    dated_post!(author, "browser three days", "Browser three days", DatesTimes.past(3, :day))
    dated_post!(author, "browser week old", "Browser week old", DatesTimes.past(7, :day))
    dated_post!(author, "browser month old", "Browser month old", DatesTimes.past(30, :day))
    dated_post!(author, "browser old", "Browser old", DatesTimes.past(60, :day))

    on_exit(fn ->
      Bonfire.Common.Cache.remove_all()
      Config.put([Bonfire.Social.Feeds, :query_with_deferred_join], original_deferred)
      Config.put(:default_pagination_limit, original_default_limit)
    end)

    :ok
  end

  @tag :browser_js
  test "guest browser JS can remove local feed time limits and continue paginating with cache bypassed" do
    run_browser_time_limit_flow("#{Bonfire.Web.Endpoint.url()}/feed/?cache=skip&time_limit=1")
  end

  @tag :browser_js
  test "guest browser JS keeps cached time-limited and all-time pages separate" do
    run_browser_time_limit_flow("#{Bonfire.Web.Endpoint.url()}/feed/?time_limit=1")
  end

  defp run_browser_time_limit_flow(url) do
    assert Application.get_env(:bonfire, Bonfire.Web.Endpoint)[:server],
           "Run this test through test-pagination-regression.sh ui-browser-js so PHX_SERVER=yes starts the endpoint."

    assert System.find_executable("npx"),
           "npx is required for the real browser JS regression target."

    script = browser_script(url)

    {output, status} =
      System.cmd(
        "npx",
        [
          "--yes",
          "-p",
          "playwright",
          "-c",
          "PW_BIN=$(which playwright); export NODE_PATH=$(dirname $(dirname $PW_BIN)); node -e #{shell_quote(script)}"
        ],
        stderr_to_stdout: true
      )

    assert status == 0, output
    assert output =~ "browser_js_time_limit"
  end

  defp dated_post!(user, summary, body, date) do
    fake_post!(user, "public", %{
      post_content: %{
        summary: summary,
        html_body: "<p>#{body}</p>"
      },
      id: DatesTimes.generate_ulid(date)
    })
  end

  defp browser_script(url) do
    """
    const { chromium } = require("playwright");

    (async () => {
      const browser = await chromium.launch({ headless: true });
      const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
      const errors = [];
      page.on("console", message => {
        if (message.type() === "error") errors.push(message.text());
      });
      page.on("pageerror", error => errors.push(error.message));

      await page.goto(#{Jason.encode!(url)}, { waitUntil: "domcontentloaded", timeout: #{@playwright_timeout} });
      await page.waitForSelector("[data-id=feed] article", { timeout: #{@playwright_timeout} });

      const articles = page.locator("[data-id=feed] article");
      const initialCount = await articles.count();
      if (initialCount !== 1) {
        throw new Error(`expected one time-limited article, got ${initialCount}`);
      }

      const loadAll = page.locator("[data-id=load_all_time]").first();
      await loadAll.waitFor({ state: "visible", timeout: #{@playwright_timeout} });
      await Promise.all([
        page.waitForURL(url => url.searchParams.get("time_limit") === "0", { timeout: #{@playwright_timeout} }),
        loadAll.click()
      ]);
      await page.waitForSelector("[data-id=feed] article", { timeout: #{@playwright_timeout} });

      const afterLoadAllCount = await articles.count();
      if (afterLoadAllCount < 2) {
        throw new Error(`expected older activities after removing time_limit, got ${afterLoadAllCount}`);
      }

      const nextPage = page.locator("a[data-id=next_page]").first();
      await nextPage.waitFor({ state: "visible", timeout: #{@playwright_timeout} });
      await Promise.all([
        page.waitForURL(url => url.searchParams.has("after") || url.toString().includes("%5Bafter%5D"), { timeout: #{@playwright_timeout} }),
        nextPage.click()
      ]);
      await page.waitForSelector("[data-id=feed] article", { timeout: #{@playwright_timeout} });

      const afterNextPageCount = await articles.count();
      if (afterNextPageCount < 1) {
        throw new Error("expected at least one activity after following the next_page link");
      }
      if (errors.length > 0) {
        throw new Error(`browser JS errors: ${errors.join(" | ")}`);
      }

      console.log(JSON.stringify({
        test: "browser_js_time_limit",
        initialCount,
        afterLoadAllCount,
        afterNextPageCount,
        url: page.url()
      }));

      await browser.close();
    })().catch(error => {
      console.error(error.stack || error.message);
      process.exit(1);
    });
    """
  end

  defp shell_quote(value) do
    "'" <> String.replace(value, "'", "'\"'\"'") <> "'"
  end
end
