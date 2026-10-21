defmodule ExampleWeb.ShopLiveTest do
  use ExampleWeb.ConnCase

  import Example.CatalogFixtures
  import Phoenix.LiveViewTest

  alias Example.Pages

  setup do
    boots =
      product_fixture(
        name: "Leather boots",
        slug: "leather-boots",
        category: "Shoes",
        price: "89990",
        description: "Stitched by hand.",
        featured: true
      )

    sneakers =
      product_fixture(name: "Sneakers", slug: "sneakers", category: "Shoes", featured: false)

    tee = product_fixture(name: "Tee", slug: "tee", category: "Shirts", featured: false)
    draft = product_fixture(name: "Hidden", slug: "hidden", category: "Shoes", published: false)

    %{boots: boots, sneakers: sneakers, tee: tee, draft: draft}
  end

  defp publish(attrs, body) do
    {:ok, page} = Pages.create_page(Map.put(attrs, :status, :published))
    {:ok, page} = Pages.update_page_body(page, body)
    page
  end

  test "the shop lists the products in loop grids", %{conn: conn} do
    publish(%{title: "Shop", slug: "shop"}, Example.Showcase.Shop.page())
    {:ok, view, html} = live(conn, ~p"/p/shop")

    assert has_element?(view, ~s(a[href="/shop/leather-boots"]))
    assert has_element?(view, ~s(a[href="/shop/tee"]))
    assert html =~ "$89,990"
    # drafts never reach the site
    refute html =~ "Hidden"
  end

  describe "pages of the loops" do
    setup do
      for n <- 1..3, do: product_fixture(name: "Extra #{n}", slug: "extra-#{n}", featured: false)
      :ok
    end

    test "the shop's catalog has numbered pages", %{conn: conn} do
      publish(%{title: "Shop", slug: "shop"}, Example.Showcase.Shop.page())

      {:ok, first, _html} = live(conn, ~p"/p/shop")
      assert has_element?(first, ~s(#catalog a[href="/shop/extra-1"]))
      assert has_element?(first, ~s(#catalog a[href="?catalog[page]=2#catalog"]))

      # 6 published products, 4 per page, by name
      {:ok, second, _html} = live(conn, "/p/shop?catalog[page]=2")
      assert has_element?(second, ~s(#catalog a[href="/shop/sneakers"]))
      assert has_element?(second, ~s(#catalog a[href="/shop/tee"]))
      refute has_element?(second, ~s(#catalog a[href="/shop/extra-1"]))
      assert has_element?(second, ~s(#catalog [aria-current="page"]), "2")
      assert has_element?(second, ~s(#catalog a[rel="prev"][href="?#catalog"]))
    end

    test "the shop's filters: search, categories, price ranges, in stock and order", %{
      conn: conn
    } do
      publish(%{title: "Shop", slug: "shop"}, Example.Showcase.Shop.page())

      product_fixture(
        name: "Rain jacket",
        slug: "rain-jacket",
        category: "Jackets",
        price: "54990",
        stock: 0,
        featured: false
      )

      {:ok, view, _html} = live(conn, ~p"/p/shop")
      form = ~s(form[data-ex-filters="catalog"][data-ex-loop="shopCatalog"])
      assert has_element?(view, form)
      assert has_element?(view, ~s(#{form} input[name="catalog[q]"]))
      # the categories are the values of the column, as buttons
      assert has_element?(
               view,
               ~s(#{form} input[type="radio"][name="catalog[category]"][value="Shoes"])
             )

      assert has_element?(
               view,
               ~s(#{form} input[type="radio"][name="catalog[category]"][value="Jackets"])
             )

      # a filter block of this app, and a filter of the source
      assert has_element?(view, ~s(#{form} input[name="catalog[price]"][value="20000..50000"]))
      assert has_element?(view, ~s(#{form} input[name="catalog[in_stock]"][value="true"]))
      assert has_element?(view, ~s(#{form} select[name="catalog[sort]"] option[value="-price"]))

      catalog = fn query ->
        {:ok, view, _html} = live(conn, "/p/shop?" <> query)
        view
      end

      shirts = catalog.("catalog[category]=Shirts")
      assert has_element?(shirts, ~s(#catalog a[href="/shop/tee"]))
      refute has_element?(shirts, ~s(#catalog a[href="/shop/sneakers"]))
      assert has_element?(shirts, ~s(#{form} input[value="Shirts"][checked]))

      found = catalog.("catalog[q]=JACK")
      assert has_element?(found, ~s(#catalog a[href="/shop/rain-jacket"]))
      refute has_element?(found, ~s(#catalog a[href="/shop/tee"]))

      in_stock = catalog.("catalog[category]=Jackets&catalog[in_stock]=true")
      refute has_element?(in_stock, ~s(#catalog a[href="/shop/rain-jacket"]))

      ranged = catalog.("catalog[price]=50000..")
      assert has_element?(ranged, ~s(#catalog a[href="/shop/rain-jacket"]))
      refute has_element?(ranged, ~s(#catalog a[href="/shop/tee"]))
    end

    test "the catalog loads the next products as the visitor scrolls", %{conn: conn} do
      publish(%{title: "Catalog", slug: "catalog"}, Example.Showcase.Shop.catalog())

      {:ok, view, _html} = live(conn, ~p"/p/catalog")

      assert has_element?(
               view,
               ~s(#products [data-ex-loop-more="scroll"][data-ex-next="?products[page]=2"])
             )

      # without JavaScript, a link to the next page
      assert has_element?(
               view,
               ~s(#products a[data-ex-loop-button][href="?products[page]=2#products"])
             )

      # the next page is what the runtime fetches: its items, and no more after it
      {:ok, next, html} = live(conn, "/p/catalog?products[page]=2")
      assert length(Regex.scan(~r/data-ex-loop-item=/, html)) == 3
      assert html =~ ~s(data-ex-loop-item="3")
      refute has_element?(next, "#products [data-ex-loop-more]")
    end
  end

  test "the page of a product is its template made in the editor", %{conn: conn} do
    publish(
      %{title: "Product page", slug: "product-page", source: "products"},
      Example.Showcase.Shop.product_template()
    )

    {:ok, view, html} = live(conn, ~p"/shop/leather-boots")

    assert html =~ "Leather boots"
    assert html =~ "Stitched by hand."
    assert html =~ "$89,990"
    assert has_element?(view, ~s(#product-page a[href*="know+more+about+Leather+boots"]))
    # related: the same category, without the product itself
    assert has_element?(view, ~s(a[href="/shop/sneakers"]))
    refute has_element?(view, ~s(a[href="/shop/tee"]))
    refute has_element?(view, ~s(a[href="/shop/leather-boots"]))
  end

  test "display conditions: featured, stock and the buy button", %{conn: conn} do
    publish(
      %{title: "Product page", slug: "product-page", source: "products"},
      Example.Showcase.Shop.product_template()
    )

    product_fixture(name: "Rain jacket", slug: "rain-jacket", stock: 0, featured: false)

    {:ok, _view, boots} = live(conn, ~p"/shop/leather-boots")
    assert boots =~ "Featured"
    assert boots =~ "42 in stock"
    assert boots =~ "Buy now"
    refute boots =~ "Sold out"

    {:ok, _view, jacket} = live(conn, ~p"/shop/rain-jacket")
    assert jacket =~ "Sold out"
    refute jacket =~ "Buy now"
    refute jacket =~ "in stock"
    refute jacket =~ ~r/>\s*Featured\s*</
  end

  test "without a template, the one made from the fields of the source", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/shop/leather-boots")

    assert html =~ "Leather boots"
    assert html =~ "89,990"
  end

  test "templates are not pages, and drafts have no page", %{conn: conn} do
    publish(
      %{title: "Product page", slug: "product-page", source: "products"},
      Example.Showcase.Shop.product_template()
    )

    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/p/product-page") end
    assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/shop/hidden") end
  end

  test "templates are created from the admin and edited with the source's fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/pages")
    assert has_element?(view, ~s(#page-form option[value="products"]))

    assert {:error, {:live_redirect, %{to: "/admin/pages/" <> id}}} =
             view
             |> form("#page-form", page: %{title: "Product page", source: "products"})
             |> render_submit()

    assert Pages.get_page!(String.trim_trailing(id, "/edit")).source == "products"

    {:ok, editor, _html} = live(conn, "/admin/pages/" <> id)
    assert has_element?(editor, "#template-source", "Products")
    # the top bar picks the product shown on the canvas
    assert has_element?(editor, ~s(select[name="record"] option), "Leather boots")
  end

  test "unknown sources are rejected" do
    assert {:error, changeset} = Pages.create_page(%{title: "X", source: "ghosts"})
    assert "is not a source of dynamic content" in Example.DataCase.errors_on(changeset).source
  end
end
