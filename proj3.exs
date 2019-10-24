defmodule Proj3 do
  def main do
    # Input of the nodes, Topology and Algorithm
    input = System.argv()
    [num_nodes, num_requests] = input
    num_nodes = String.to_integer(num_nodes)
    num_requests = String.to_integer(num_requests)

    list_of_hexValues =
      Enum.map(1..(num_nodes + 1), fn nodeID ->
        String.to_charlist(:crypto.hash(:sha, "#{nodeID}") |> Base.encode16())
      end)

    #table for linking hash with their pids
    :ets.new(:indexed_actors, [:named_table, :public])

    #using supervisor to initialise all the workers
    children =
      Enum.map(list_of_hexValues, fn hash ->
        Supervisor.child_spec({Tapestryworker, []}, id: hash, restart: :permanent)
      end)

    opts = [strategy: :one_for_one, name: Tapestrysupervisor]
    Supervisor.start_link(children, opts)
    result = Supervisor.which_children(Tapestrysupervisor)

    Enum.map(result, fn {hash, pid, _, _} ->
      :ets.insert(:indexed_actors, {hash, pid})
    end)

    list_without_newNode = list_of_hexValues -- [List.last(list_of_hexValues)]

    #creating routing tables for all nodes except the last node
    Enum.map(list_without_newNode, fn hash_key ->
      fill_routing_table(
        hash_key,
        list_of_hexValues -- [hash_key]
      )
    end)

    #inserting last node as a newNode into the network
    new_num_node = List.last(list_of_hexValues)
    node_insertion(new_num_node, list_without_newNode)

    #Start Hopping
    Enum.map(list_of_hexValues, fn source_ID ->
      destinationList = Enum.take_random(list_of_hexValues -- [source_ID], num_requests)

      [{_, pid}] = :ets.lookup(:indexed_actors, source_ID)

      implementing_tapestry(
        source_ID,
        pid,
        destinationList
      )
    end)

    hopping_list =
      Enum.reduce(list_of_hexValues, [], fn hash_key, list ->
        [{_, pid}] = :ets.lookup(:indexed_actors, hash_key)
        list ++ [GenServer.call(pid, :getState)]
      end)

    max_hops = Enum.max(hopping_list)
    IO.puts("Maximum Hops = #{max_hops}")
  end

  def implementing_tapestry(
        node_ID,
        pid,
        destinationList
      ) do
    Enum.map(destinationList, fn dest_ID ->
      GenServer.cast(
        pid,
        {:update_next_hop, node_ID, dest_ID, 1}
      )
    end)
  end

  def fill_routing_table(hash_key, list_of_neighbors) do
    Enum.reduce(
      list_of_neighbors,
      :ets.new(String.to_atom("Table_#{hash_key}"), [:named_table, :public]),
      fn neighbor_key, _acc ->
        key = common_prefix(hash_key, neighbor_key)

        if :ets.lookup(String.to_atom("Table_#{hash_key}"), key) != [] do
          [{_, already_in_map_hexVal}] = :ets.lookup(String.to_atom("Table_#{hash_key}"), key)
          {hash_key_integer, _} = Integer.parse(List.to_string(hash_key), 16)
          {already_in_map_integer, _} = Integer.parse(List.to_string(already_in_map_hexVal), 16)
          {neighbor_key_integer, _} = Integer.parse(List.to_string(neighbor_key), 16)

          dist1 = abs(hash_key_integer - already_in_map_integer)
          dist2 = abs(hash_key_integer - neighbor_key_integer)

          if dist1 < dist2 do
            :ets.insert(String.to_atom("Table_#{hash_key}"), {key, already_in_map_hexVal})
          else
            :ets.insert(String.to_atom("Table_#{hash_key}"), {key, neighbor_key})
          end
        else
          :ets.insert(String.to_atom("Table_#{hash_key}"), {key, neighbor_key})
        end
      end
    )
  end

  def common_prefix(hash_key, neighbor_key) do
    Enum.reduce_while(neighbor_key, 0, fn char, level ->
      if Enum.at(hash_key, level) == char,
        do: {:cont, level + 1},
        else: {:halt, {level, List.to_string([char])}}
    end)
  end

  def node_insertion(new_num_node, list_without_newNode) do
    Enum.map(list_without_newNode, fn neighbor_hash ->
      key = common_prefix(neighbor_hash, new_num_node)

      if :ets.lookup(String.to_atom("Table_#{neighbor_hash}"), key) != [] do
        [{_, existingMapHashID}] = :ets.lookup(String.to_atom("Table_#{neighbor_hash}"), key)
        {hashKeyIntegerVal, _} = Integer.parse(List.to_string(neighbor_hash), 16)
        {existingMapIntegerVal, _} = Integer.parse(List.to_string(existingMapHashID), 16)
        {neighborKeyIntegerVal, _} = Integer.parse(List.to_string(new_num_node), 16)

        distance1 = abs(hashKeyIntegerVal - existingMapIntegerVal)
        distance2 = abs(hashKeyIntegerVal - neighborKeyIntegerVal)

        if distance1 < distance2 do
          :ets.insert(String.to_atom("Table_#{neighbor_hash}"), {key, existingMapHashID})
        else
          :ets.insert(String.to_atom("Table_#{neighbor_hash}"), {key, new_num_node})
        end
      else
        :ets.insert(String.to_atom("Table_#{neighbor_hash}"), {key, new_num_node})
      end
    end)

    fill_routing_table(new_num_node, list_without_newNode)
  end
end

defmodule Tapestryworker do
  use GenServer

  def start_link(_args) do
    {:ok, pid} = GenServer.start_link(__MODULE__, 1)
    {:ok, pid}
  end

  def init(hops) do
    {:ok, hops}
  end

  def nextHop(new_node_ID, dest_ID, total_hops) do
    [{_, pid}] = :ets.lookup(:indexed_actors, new_node_ID)

    GenServer.cast(
      pid,
      {:update_next_hop, new_node_ID, dest_ID, total_hops}
    )
  end

  def handle_cast(
        {:update_next_hop, node_ID, dest_ID, total_hops},
        _state
      ) do
    key = Proj3.common_prefix(node_ID, dest_ID)
    [{_, new_node_ID}] = :ets.lookup(String.to_atom("Table_#{node_ID}"), key)

    state = {node_ID, total_hops}

    if(new_node_ID == dest_ID) do
      {:noreply, state}
    else
      nextHop(
        new_node_ID,
        dest_ID,
        total_hops + 1
      )

      {:noreply, state}
    end
  end

  def handle_call(:getState, _from, state) do
    {_, hops} = state
    {:reply, hops, state}
  end
end

Proj3.main()
