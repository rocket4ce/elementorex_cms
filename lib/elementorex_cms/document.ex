defmodule ElementorexCms.Document do
  @moduledoc """
  The document: a tree of nodes stored as plain JSON (a `jsonb` column).

      %{
        "version" => 1,
        "root" => %{
          "id" => "Wq0m2Lx9Ka",
          "type" => "root",
          "props" => %{},
          "style" => %{},
          "attrs" => %{"css" => "selector { padding: 8px }"},
          "children" => [
            %{
              "id" => "b3Rt9Lm1Qe",
              "type" => "heading",
              "props" => %{"text" => "Hello", "level" => "h2"},
              "style" => %{"desktop" => %{"color" => "var(--color-primary)"}, "mobile" => %{"font-size" => "28px"}},
              "attrs" => %{"class" => "tracking-tight", "hide_on" => ["mobile"]},
              "children" => []
            }
          ]
        }
      }

  Every node has:

    * `"id"` - stable id (`ElementorexCms.Id`)
    * `"type"` - the block type (`ElementorexCms.Registry`)
    * `"props"` - content of the block, as declared by its props
    * `"style"` - declarations per state: `"desktop"`, `"tablet"`, `"mobile"`
      and `"hover"` (see `ElementorexCms.Style`)
    * `"attrs"` - *Advanced* settings: `"id"`, `"class"`, `"hide_on"`, `"css"`,
      `"animation"`, `"animation_delay"`, `"label"` (name in the tree) and
      `"condition"` (display condition, see `ElementorexCms.Dynamic`)
    * `"children"` - child nodes (containers only)
    * `"dynamic"` - only when some prop is bound to dynamic content: the
      bindings of the props, by key (see `ElementorexCms.Dynamic`)

  The functions here are pure: they take a document and return a new one.
  Tree operations validate what they are asked (a node cannot go inside itself,
  only containers take children, the root cannot be removed) and return
  `{:error, reason}` otherwise.
  """

  alias ElementorexCms.Block
  alias ElementorexCms.Block.Prop
  alias ElementorexCms.CSS
  alias ElementorexCms.Dynamic
  alias ElementorexCms.Id
  alias ElementorexCms.Registry

  @version 1
  @max_nodes 2_000
  @max_depth 24
  @states ~w(desktop tablet mobile hover)
  @devices ~w(desktop tablet mobile)
  @animations ~w(fade-in fade-up fade-down fade-left fade-right zoom-in)

  @type t :: map()
  @type tree_node :: map()

  @doc "Current version of the document format."
  def version, do: @version

  @doc "Style states a node can have (`desktop`, `tablet`, `mobile`, `hover`)."
  def states, do: @states

  @doc "Devices of the responsive styles."
  def devices, do: @devices

  @doc "Entrance animations of the *Advanced* tab."
  def animations, do: @animations

  @doc "Limits applied by `normalize/2`: `%{nodes: #{@max_nodes}, depth: #{@max_depth}}`."
  def limits, do: %{nodes: @max_nodes, depth: @max_depth}

  @doc "An empty document, optionally with root children."
  @spec new([tree_node()]) :: t()
  def new(children \\ []) do
    %{"version" => @version, "root" => node("root", %{}, children: children)}
  end

  @doc """
  A new node of `type`. `props` are stored as given (string keys); pass
  `registry:` to fill in the defaults of the block and its default children.

  Options: `:children`, `:style`, `:attrs`, `:id`, `:registry` and `:dynamic`
  (bindings of props to fields, see `ElementorexCms.Dynamic`).
  """
  @spec node(String.t(), map(), keyword()) :: tree_node()
  def node(type, props \\ %{}, opts \\ []) do
    props = Map.new(props, fn {key, value} -> {to_string(key), value} end)
    block = opts[:registry] && Registry.fetch(opts[:registry], type)

    {props, children, style} =
      case block do
        nil ->
          {props, Keyword.get(opts, :children, []), Keyword.get(opts, :style, %{})}

        block ->
          props = Map.merge(Block.default_props(block), Block.cast_props(block, props))
          children = Keyword.get_lazy(opts, :children, fn -> block.default_children() end)
          {props, children, Keyword.get(opts, :style, block.meta()[:style] || %{})}
      end

    %{
      "id" => Keyword.get_lazy(opts, :id, &Id.generate/0),
      "type" => to_string(type),
      "props" => props,
      "style" => style,
      "attrs" => Keyword.get(opts, :attrs, %{}),
      "children" => children
    }
    |> put_dynamic(Dynamic.normalize(Keyword.get(opts, :dynamic, %{}), block))
  end

  defp put_dynamic(node, dynamic) when dynamic == %{}, do: Map.delete(node, "dynamic")
  defp put_dynamic(node, dynamic), do: Map.put(node, "dynamic", dynamic)

  @doc "The root node."
  @spec root(t()) :: tree_node()
  def root(%{"root" => root}), do: root

  @doc "Whether the document has no content."
  @spec empty?(t() | nil) :: boolean()
  def empty?(%{"root" => %{"children" => [_ | _]}}), do: false
  def empty?(_doc), do: true

  ## Queries

  @doc "The node with `id`, or `nil`."
  @spec get(t(), String.t() | nil) :: tree_node() | nil
  def get(_doc, nil), do: nil
  def get(%{"root" => root}, id), do: find(root, id)

  @doc "Like `get/2`, as `{:ok, node}` or `{:error, :not_found}`."
  @spec fetch(t(), String.t() | nil) :: {:ok, tree_node()} | {:error, :not_found}
  def fetch(doc, id) do
    case get(doc, id) do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  defp find(%{"id" => id} = node, id), do: node

  defp find(%{"children" => children}, id) when is_list(children) do
    Enum.find_value(children, &find(&1, id))
  end

  defp find(_node, _id), do: nil

  @doc """
  Nodes from the root down to the node with `id` (both included), or `[]` if
  it does not exist.
  """
  @spec path(t(), String.t()) :: [tree_node()]
  def path(%{"root" => root}, id), do: path_to(root, id, [])

  defp path_to(%{"id" => id} = node, id, acc), do: Enum.reverse([node | acc])

  defp path_to(%{"children" => children} = node, id, acc) when is_list(children) do
    Enum.find_value(children, [], fn child ->
      case path_to(child, id, [node | acc]) do
        [] -> nil
        path -> path
      end
    end)
  end

  defp path_to(_node, _id, _acc), do: []

  @doc "The parent of the node with `id` and the node's index in it."
  @spec parent(t(), String.t()) :: {:ok, tree_node(), non_neg_integer()} | :error
  def parent(doc, id) do
    case path(doc, id) do
      [_ | _] = path when length(path) >= 2 ->
        parent = Enum.at(path, -2)
        index = Enum.find_index(parent["children"], &(&1["id"] == id))
        {:ok, parent, index}

      _ ->
        :error
    end
  end

  @doc "Whether `id` is `ancestor_id` or one of its descendants."
  @spec within?(t(), String.t(), String.t()) :: boolean()
  def within?(doc, id, ancestor_id) do
    doc |> path(id) |> Enum.any?(&(&1["id"] == ancestor_id))
  end

  @doc "Every node, depth first, the root included."
  @spec nodes(t() | tree_node()) :: [tree_node()]
  def nodes(%{"root" => root}), do: nodes(root)

  def nodes(%{} = node) do
    [node | Enum.flat_map(node["children"] || [], &nodes/1)]
  end

  @doc "Number of nodes, the root included."
  @spec count(t() | tree_node()) :: non_neg_integer()
  def count(doc), do: length(nodes(doc))

  ## Changes

  @doc """
  Applies `fun` to the node with `id`. The id and type cannot change.
  """
  @spec update(t(), String.t(), (tree_node() -> tree_node())) :: {:ok, t()} | {:error, :not_found}
  def update(%{"root" => root} = doc, id, fun) do
    case update_tree(root, id, fun) do
      {:ok, root} -> {:ok, %{doc | "root" => root}}
      :error -> {:error, :not_found}
    end
  end

  defp update_tree(%{"id" => id, "type" => type} = node, id, fun) do
    {:ok, %{fun.(node) | "id" => id, "type" => type}}
  end

  defp update_tree(%{"children" => children} = node, id, fun) when is_list(children) do
    children
    |> Enum.with_index()
    |> Enum.find_value(:error, fn {child, index} ->
      case update_tree(child, id, fun) do
        {:ok, child} -> {:ok, %{node | "children" => List.replace_at(children, index, child)}}
        :error -> nil
      end
    end)
  end

  defp update_tree(_node, _id, _fun), do: :error

  @doc "Sets a prop of a node (the value is stored as given; cast it first)."
  @spec put_prop(t(), String.t(), String.t(), term()) :: {:ok, t()} | {:error, :not_found}
  def put_prop(doc, id, key, value) do
    update(doc, id, fn node ->
      Map.update(node, "props", %{key => value}, &Map.put(&1 || %{}, key, value))
    end)
  end

  @doc """
  Binds a prop of a node to a field of dynamic content (see
  `ElementorexCms.Dynamic`): `binding` is a field key or a map with `"field"`
  and its settings. Props that cannot be bound and invalid bindings give
  `{:error, :invalid}`.
  """
  @spec put_binding(t(), String.t(), String.t(), term(), Registry.t() | nil) ::
          {:ok, t()} | {:error, :not_found | :invalid}
  def put_binding(doc, id, key, binding, registry \\ nil) do
    registry = registry || Registry.default()

    with {:ok, node} <- fetch(doc, id),
         block when not is_nil(block) <- Registry.fetch(registry, node["type"]),
         %Prop{} = prop <- Block.find_prop(block, key),
         true <- Dynamic.bindable?(prop),
         %{} = binding <- Dynamic.normalize_binding(binding) do
      update(doc, id, fn node ->
        put_dynamic(node, Map.put(node["dynamic"] || %{}, prop.key, binding))
      end)
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid}
    end
  end

  @doc "Removes the binding of a prop of a node: the prop shows its own value again."
  @spec drop_binding(t(), String.t(), String.t()) :: {:ok, t()} | {:error, :not_found}
  def drop_binding(doc, id, key) do
    update(doc, id, fn node -> put_dynamic(node, Map.delete(node["dynamic"] || %{}, key)) end)
  end

  @doc """
  Sets (or with `nil`/`""` removes) a style declaration of a node for a state
  (`"desktop"`, `"tablet"`, `"mobile"` or `"hover"`). Invalid values are
  rejected with `{:error, :invalid}`.
  """
  @spec put_style(t(), String.t(), String.t(), String.t(), term()) ::
          {:ok, t()} | {:error, :not_found | :invalid}
  def put_style(doc, id, state, property, value) when state in @states do
    cond do
      value in [nil, ""] ->
        update(doc, id, &drop_style(&1, state, property))

      valid = CSS.value(property, value) ->
        # Presets (shadows) are stored by name and expanded when writing CSS.
        stored = if property == "box-shadow", do: value, else: valid

        update(doc, id, fn node ->
          styles = node["style"] || %{}
          state_styles = Map.put(styles[state] || %{}, property, stored)
          Map.put(node, "style", Map.put(styles, state, state_styles))
        end)

      true ->
        {:error, :invalid}
    end
  end

  def put_style(_doc, _id, _state, _property, _value), do: {:error, :invalid}

  defp drop_style(node, state, property) do
    styles = node["style"] || %{}

    state_styles = Map.delete(styles[state] || %{}, property)

    styles =
      if state_styles == %{},
        do: Map.delete(styles, state),
        else: Map.put(styles, state, state_styles)

    Map.put(node, "style", styles)
  end

  @doc "Removes every style of a node (all states)."
  @spec clear_style(t(), String.t()) :: {:ok, t()} | {:error, :not_found}
  def clear_style(doc, id), do: update(doc, id, &Map.put(&1, "style", %{}))

  @doc """
  Sets an *Advanced* attribute of a node (validated with `normalize_attrs/1`;
  an invalid value removes the attribute).
  """
  @spec put_attr(t(), String.t(), String.t(), term()) :: {:ok, t()} | {:error, :not_found}
  def put_attr(doc, id, key, value) do
    update(doc, id, fn node ->
      attrs = (node["attrs"] || %{}) |> Map.put(key, value) |> normalize_attrs()
      Map.put(node, "attrs", attrs)
    end)
  end

  @doc """
  Inserts `node` in the container `parent_id` at `index` (clamped to the
  children list). Checks that the parent takes that kind of child and the
  document limits.
  """
  @spec insert(t(), tree_node(), String.t(), integer(), Registry.t() | nil) ::
          {:ok, t()} | {:error, atom()}
  def insert(doc, node, parent_id, index, registry \\ nil) do
    registry = registry || Registry.default()

    with {:ok, parent} <- fetch(doc, parent_id),
         :ok <- accepts(registry, parent, node),
         :ok <- within_limits(doc, node, parent_id) do
      node = if ids_taken?(doc, node), do: regenerate_ids(node), else: node

      update(doc, parent_id, fn parent ->
        children = parent["children"] || []
        index = index |> max(0) |> min(length(children))
        %{parent | "children" => List.insert_at(children, index, node)}
      end)
    end
  end

  @doc """
  Moves the node `id` into `parent_id` at `index`. The index is counted in the
  target's current children (the node itself included when it already is
  there), which is what the editor's drop indicator shows.
  """
  @spec move(t(), String.t(), String.t(), integer(), Registry.t() | nil) ::
          {:ok, t()} | {:error, atom()}
  def move(doc, id, parent_id, index, registry \\ nil) do
    registry = registry || Registry.default()

    with {:ok, node} <- fetch(doc, id),
         :ok <- not_root(node),
         :ok <- not_within(doc, parent_id, id),
         {:ok, target} <- fetch(doc, parent_id),
         :ok <- accepts(registry, target, node),
         {:ok, old_parent, old_index} <- parent(doc, id) do
      index =
        if old_parent["id"] == parent_id and old_index < index, do: index - 1, else: index

      if old_parent["id"] == parent_id and old_index == index do
        {:ok, doc}
      else
        {:ok, without} = remove(doc, id)

        update(without, parent_id, fn parent ->
          children = parent["children"] || []
          index = index |> max(0) |> min(length(children))
          %{parent | "children" => List.insert_at(children, index, node)}
        end)
      end
    else
      :error -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp not_root(%{"type" => "root"}), do: {:error, :root}
  defp not_root(_node), do: :ok

  defp not_within(doc, parent_id, id) do
    if within?(doc, parent_id, id), do: {:error, :into_itself}, else: :ok
  end

  @doc "Removes the node `id` and its children. The root cannot be removed."
  @spec remove(t(), String.t()) :: {:ok, t()} | {:error, atom()}
  def remove(doc, id) do
    case parent(doc, id) do
      {:ok, parent, _index} ->
        update(doc, parent["id"], fn parent ->
          %{parent | "children" => Enum.reject(parent["children"], &(&1["id"] == id))}
        end)

      :error ->
        if get(doc, id), do: {:error, :root}, else: {:error, :not_found}
    end
  end

  @doc """
  Copies the node `id` (with new ids for it and its children) right after it.
  Returns the document and the id of the copy.
  """
  @spec duplicate(t(), String.t(), Registry.t() | nil) ::
          {:ok, t(), String.t()} | {:error, atom()}
  def duplicate(doc, id, registry \\ nil) do
    with {:ok, node} <- fetch(doc, id),
         {:ok, parent, index} <- parent(doc, id) do
      copy = regenerate_ids(node)

      case insert(doc, copy, parent["id"], index + 1, registry) do
        {:ok, doc} -> {:ok, doc, copy["id"]}
        error -> error
      end
    else
      :error -> {:error, :root}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  A copy of a node (or of a whole document) with new ids everywhere. Props that
  point to a node of the copy (the loop grid a filter form filters) point to
  its copy.
  """
  @spec regenerate_ids(t() | tree_node()) :: t() | tree_node()
  def regenerate_ids(%{"root" => root} = doc), do: %{doc | "root" => regenerate_ids(root)}

  def regenerate_ids(%{} = node) do
    {node, ids} = renew_ids(node, %{})
    remap_ids(node, ids)
  end

  defp renew_ids(node, ids) do
    id = Id.generate()
    ids = if is_binary(node["id"]), do: Map.put(ids, node["id"], id), else: ids
    {children, ids} = Enum.map_reduce(node["children"] || [], ids, &renew_ids/2)
    {node |> Map.put("id", id) |> Map.put("children", children), ids}
  end

  defp remap_ids(node, ids) do
    props =
      Map.new(node["props"] || %{}, fn {key, value} ->
        {key, if(is_binary(value), do: Map.get(ids, value, value), else: value)}
      end)

    node
    |> Map.put("props", props)
    |> Map.put("children", Enum.map(node["children"], &remap_ids(&1, ids)))
  end

  defp ids_taken?(doc, node) do
    existing = doc |> nodes() |> MapSet.new(& &1["id"])
    node |> nodes() |> Enum.any?(&MapSet.member?(existing, &1["id"]))
  end

  defp accepts(registry, parent, node) do
    if Registry.accepts?(registry, parent["type"], node["type"]),
      do: :ok,
      else: {:error, :not_allowed}
  end

  defp within_limits(doc, node, parent_id) do
    depth = length(path(doc, parent_id)) + depth_of(node)

    cond do
      count(doc) + count(node) > @max_nodes -> {:error, :too_many_nodes}
      depth > @max_depth -> {:error, :too_deep}
      true -> :ok
    end
  end

  defp depth_of(%{"children" => [_ | _] = children}),
    do: 1 + Enum.max(Enum.map(children, &depth_of/1))

  defp depth_of(_node), do: 1

  ## Normalization

  @doc """
  Makes any map a valid document for `registry`: fills missing keys, casts and
  sanitizes props with the definitions of each block, keeps only valid styles
  and *Advanced* attributes, drops children of non-containers, gives new ids to
  invalid or repeated ones and enforces the limits (`limits/0`).

  Nodes of unknown types are kept as they are (they render nothing), so a
  document never loses content because a block was removed from the registry.

  Run it on everything that comes from outside: stored JSON, imports, the
  editor's events.
  """
  @spec normalize(term(), Registry.t() | nil) :: t()
  def normalize(doc, registry \\ nil)

  def normalize(json, registry) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, map} -> normalize(map, registry)
      {:error, _} -> new()
    end
  end

  def normalize(%{"root" => %{} = root}, registry) do
    registry = registry || Registry.default()
    root = Map.put(root, "type", "root")

    {root, _state} = normalize_node(root, registry, 1, %{seen: MapSet.new(), count: 0})
    %{"version" => @version, "root" => root}
  end

  def normalize(%{root: _} = doc, registry), do: doc |> stringify() |> normalize(registry)
  def normalize(_other, _registry), do: new()

  defp stringify(%{} = map) do
    Map.new(map, fn {key, value} -> {to_string(key), stringify(value)} end)
  end

  defp stringify(list) when is_list(list), do: Enum.map(list, &stringify/1)
  defp stringify(value), do: value

  defp normalize_node(node, registry, depth, state) do
    node = Map.new(node, fn {key, value} -> {to_string(key), value} end)
    type = if is_binary(node["type"]), do: node["type"], else: "unknown"

    id =
      if Id.valid?(node["id"]) and not MapSet.member?(state.seen, node["id"]),
        do: node["id"],
        else: Id.generate()

    state = %{state | seen: MapSet.put(state.seen, id), count: state.count + 1}
    block = Registry.fetch(registry, type)

    props =
      case {block, node["props"]} do
        {nil, props} when is_map(props) -> props
        {nil, _} -> %{}
        {block, props} -> Block.cast_props(block, props || %{})
      end

    container? = (block && block.meta().container) || (block == nil and is_list(node["children"]))

    {children, state} =
      if container? and depth < @max_depth do
        node["children"]
        |> List.wrap()
        |> Enum.filter(&is_map/1)
        |> Enum.reduce({[], state}, fn child, {acc, state} ->
          if state.count >= @max_nodes do
            {acc, state}
          else
            {child, state} = normalize_node(child, registry, depth + 1, state)
            {[child | acc], state}
          end
        end)
        |> then(fn {children, state} -> {Enum.reverse(children), state} end)
      else
        {[], state}
      end

    normalized =
      put_dynamic(
        %{
          "id" => id,
          "type" => type,
          "props" => props,
          "style" => normalize_style(node["style"]),
          "attrs" => normalize_attrs(node["attrs"]),
          "children" => children
        },
        Dynamic.normalize(node["dynamic"], block)
      )

    {normalized, state}
  end

  @doc "Keeps only valid states and declarations of a style map."
  @spec normalize_style(term()) :: map()
  def normalize_style(style) when is_map(style) do
    for {state, declarations} <- style,
        state = to_string(state),
        state in @states,
        is_map(declarations),
        valid = valid_declarations(declarations),
        valid != %{},
        into: %{} do
      {state, valid}
    end
  end

  def normalize_style(_style), do: %{}

  defp valid_declarations(declarations) do
    for {property, value} <- declarations,
        property = to_string(property),
        CSS.value(property, value) != nil,
        into: %{} do
      {property, to_string(value)}
    end
  end

  @doc "Keeps only valid *Advanced* attributes."
  @spec normalize_attrs(term()) :: map()
  def normalize_attrs(attrs) when is_map(attrs) do
    attrs = Map.new(attrs, fn {key, value} -> {to_string(key), value} end)

    %{}
    |> put_valid("id", attrs["id"], &(is_binary(&1) and &1 =~ ~r/\A[A-Za-z][\w-]{0,63}\z/))
    |> put_valid("class", clean_classes(attrs["class"]), &(&1 != ""))
    |> put_valid("hide_on", clean_devices(attrs["hide_on"]), &(&1 != []))
    |> put_valid(
      "css",
      attrs["css"],
      &(is_binary(&1) and String.trim(&1) != ""),
      &String.slice(&1, 0, 20_000)
    )
    |> put_valid("animation", attrs["animation"], &(&1 in @animations))
    |> put_valid(
      "animation_delay",
      attrs["animation_delay"],
      &(is_integer(&1) and &1 in 0..5000),
      & &1
    )
    |> put_valid(
      "label",
      attrs["label"],
      &(is_binary(&1) and String.trim(&1) != ""),
      &String.slice(String.trim(&1), 0, 60)
    )
    |> put_valid("condition", Dynamic.normalize_condition(attrs["condition"]), &is_map/1)
  end

  def normalize_attrs(_attrs), do: %{}

  defp put_valid(map, key, value, valid?, transform \\ & &1) do
    if valid?.(value), do: Map.put(map, key, transform.(value)), else: map
  end

  defp clean_classes(classes) when is_binary(classes) do
    classes
    |> String.split()
    |> Enum.filter(&(&1 =~ ~r/\A[A-Za-z0-9_:\-\/\[\]\.%#!()&,]{1,80}\z/))
    |> Enum.reject(&String.starts_with?(&1, "exr-"))
    |> Enum.uniq()
    |> Enum.take(40)
    |> Enum.join(" ")
  end

  defp clean_classes(_classes), do: ""

  defp clean_devices(devices) when is_list(devices) do
    devices |> Enum.map(&to_string/1) |> Enum.filter(&(&1 in @devices)) |> Enum.uniq()
  end

  defp clean_devices(_devices), do: []

  ## JSON

  @doc "Encodes a document as JSON."
  @spec to_json(t(), keyword()) :: String.t()
  def to_json(doc, opts \\ []), do: Jason.encode!(doc, opts)

  @doc "Decodes and normalizes a JSON document (an invalid one gives `new/0`)."
  @spec from_json(String.t(), Registry.t() | nil) :: t()
  def from_json(json, registry \\ nil) when is_binary(json), do: normalize(json, registry)
end
