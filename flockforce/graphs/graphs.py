import numpy as np
import matplotlib.pyplot as plt

# Define the number of boid particles (x-axis)
num_boids = np.linspace(10, 100000, 100)  # From 10 to 1000 particles

# Compute the total computational load for an O(N^2) algorithm
computational_load = num_boids ** 2

# Plot the graph
plt.figure(figsize=(10, 6))
plt.plot(num_boids, computational_load, label="Computational load versus boid particle count", color="blue")

# Set Y-axis to log scale
plt.xscale('log')
plt.yscale('log')

# Label the axes
plt.xlabel("Number of boid particles (log scale)", fontsize=12)
plt.ylabel("Total computational load (log scale)", fontsize=12)

# Add a title and legend
plt.title("Scaling of Boids Algorithm with Naive Neighborhood Search", fontsize=14)
plt.legend()

# Show the grid
plt.grid(True, linestyle="--", alpha=0.6)

# Display the plot
plt.show()