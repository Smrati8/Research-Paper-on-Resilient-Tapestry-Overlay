# Research Paper implementation on Tapestry Algorithm
Tapestry is a decentralized distributed system. It is an overlay network that implements simple
key-based routing. Each node serves as both an object store and a router that applications can
contact to obtain objects. In a Tapestry network, objects are “published” at nodes, and once an
object has been successfully published, it is possible for any other node in the network to find the
location at which that object is published.

# Steps to run the program:-

1. Download the file and unzip it

2. Run the command: mix run project3.exs 1000 1

3. For bonus part run the command: mix run project3.exs 1000 1 3

# What is working?

• In our assumption of tapestry algorithm, we are taking the input of numNodes and numRequests. Out of which we are creating the routing table for numNodes - 1 nodes. The last node is being inserted dynamically in the system.

• We are using SHA1 function to generate our hash. Each node is represented by a unique hash containing 40-digit hexadecimal number.

Example: '5B384CE32D8CDEF02BC3A139D4CAC0A22BB029E8'
:crypto.hash(:sha, "#{nodeID}") |> Base.encode16()
