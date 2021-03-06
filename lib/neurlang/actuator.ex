
alias Neurlang.ConnectedNode, as: ConnectedNode
alias Neurlang.Accumulator, as: Accumulator
alias Neurlang.Actuator, as: Actuator

defrecord Neurlang.Actuator, inbound_connections: [], outbound_connections: [], 
										         barrier: HashDict.new do
 
  @moduledoc """
  Metadata for the Actuator node:

	* `inbound_connections` - a list of pid's of neurons nodes this actuator should expect to receive input from

	* `outbound_connections` - a list of pid's of output nodes this actuator process should send output to. 
                             added for testing purposes, but could have other uses as well.

	* `barrier` - used to wait until receiving inputs from all connected input nodes before sending output

  """
	use Neurlang

	record_type inbound_connections: [pid]
	record_type outbound_connections: [pid]
	record_type barrier: Dict

	@spec start_node(Actuator.options | Actuator.t) :: pid
	def start_node(keywords) when is_list(keywords) do
		start_node(new(keywords))
	end
	def start_node(actuator) do
		{:ok, pid} = NodeProcess.start_link(actuator)
		pid
	end

end

defimpl Accumulator, for: Actuator do

	def create_barrier(node) do
		node.barrier(HashDict.new)
	end

	def update_barrier_state(node, {from_pid, input_value}) do
		node.barrier( Dict.put(node.barrier(), from_pid, input_value) )
	end

	def is_barrier_satisfied?(Actuator[inbound_connections: inbound_connections, barrier: barrier]) do
		inbound_connections_accounted = Enum.filter(inbound_connections, fn(pid) -> 
																																				 HashDict.has_key?(barrier, pid) 
																																		 end)
		length(inbound_connections_accounted) == length(inbound_connections)																					
	end


	def compute_output(node) do
			barrier = node.barrier()
			inbound_connections = node.inbound_connections()
			received_inputs = lc input_node_pid inlist inbound_connections, do: barrier[input_node_pid]
			List.flatten( received_inputs ) 
	end

	def propagate_output(node, output) do
		message = { self(), :forward, output }
		Enum.each node.outbound_connections(), fn(node_pid) -> 
																								node_pid <- message 
																						end
	end

	def sync(node) do
		if node, do: throw "Actuators do not have sync functionality yet"
		node
	end

end


defimpl ConnectedNode, for: Actuator do

	import Neurlang, only: [validate_pid: 1]

	def add_inbound_connection(node, _from_node_pid, _weights) do
		if node, do: throw "Actuator inbound connections do not have weights associated with them"
		node
	end

	def add_inbound_connection(node, from_node_pid) do 
		validate_pid(from_node_pid)
		inbound_connection = from_node_pid  
		node.inbound_connections([inbound_connection | node.inbound_connections()])
	end
	
	def add_outbound_connection(node, to_node_pid) do
		validate_pid(to_node_pid)
		node.outbound_connections([to_node_pid | node.outbound_connections()])
	end

end