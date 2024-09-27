from TestSim import TestSim

def main():
    # Initialize the simulation
    s = TestSim()

    # Start the simulation with a small runtime buffer
    s.runTime(1)

    # Load the network topology and noise model
    s.loadTopo("long_line.topo")
    s.loadNoise("no_noise.txt")

    # Boot up all the motes (nodes)
    s.bootAll()

    # Add necessary channels to the simulation output
    s.addChannel(s.COMMAND_CHANNEL)   # For command handling logs
    s.addChannel(s.GENERAL_CHANNEL)   # For general debug logs
    s.addChannel(s.NEIGHBOR_CHANNEL)  # For neighbor discovery logs

    # Simulate enough time for nodes to discover neighbors (30 seconds)
    s.runTime(30720000)  # Simulate 30 seconds in TOSSIM ticks (30,720,000 ticks)

    # Ping between nodes to check message delivery
    s.ping(2, 3, "Hello, World")
    s.runTime(1024000)  # Simulate 1 second after ping

    s.ping(1, 10, "Hi!")
    s.runTime(1024000)  # Simulate 1 second after ping

    # Run more time to observe neighbor beacons and messages
    s.runTime(30720000)  # Simulate another 30 seconds in ticks

    # Optionally, check neighbor tables after some time
    for i in range(1, 11):
        s.neighborDump(i)  # Custom command to dump neighbor table of each node

    # Simulate more time for neighbor discovery
    s.runTime(30720000)  # Simulate an additional 30 seconds to ensure more beacons are exchanged


if __name__ == '__main__':
    main()