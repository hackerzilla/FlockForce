import numpy as np
import matplotlib.pyplot as plt

# Define the number of boid particles (x-axis)
num_boids = np.linspace(10, 100000, 100)  # From 10 to 1000 particles

# Compute the total computational load for an O(N^2) algorithm
computational_load = num_boids ** 2

# Point 1: Example coordinates (e.g., for 50 boids)
point1_x = 100 
point1_y = point1_x ** 2
point1_label = f'CPU implementation max boids at 60 FPS ({point1_x} boids)'
point1_color = 'red'

# Point 2: Example coordinates (e.g., for 5000 boids)
point2_x = 1000 
point2_y = point2_x ** 2
point2_label = f'GPU implementation max boids at 60 FPS ({point2_x} boids)'
point2_color = 'green'

# Plot the graph
plt.figure(figsize=(10, 6))
plt.plot(num_boids, computational_load, label="Computational load versus boid particle count", color="blue")

# Add the first specific point using plt.scatter
plt.scatter(point1_x, point1_y, color=point1_color, label=point1_label, s=100, marker='o', zorder=2) # s=size, zorder=2 puts it on top

# Add the second specific point using plt.scatter
plt.scatter(point2_x, point2_y, color=point2_color, label=point2_label, s=100, marker='^', zorder=2) # Using a different marker (triangle)

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