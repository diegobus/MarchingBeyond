# MarchingBeyond

## Overview

This project is a Unity-based implementation of raymarching and fractal rendering using Unity's Universal Render Pipeline (URP). It includes custom shaders, render features, and scripts for rendering signed distance functions (SDFs) and complex fractal geometry in real-time.

## Features

- **Raymarching Implementation**: Uses signed distance functions (SDFs) for rendering procedural geometry.
- **Fractal Rendering**: Implements a fractal SDF for generating intricate, infinite fractal structures.
- **Custom URP Render Features**: Hooks into the Unity render pipeline to apply raymarching effects.
- **Dynamic Lighting and Shadows**: Real-time lighting and shadow calculations using SDFs.
- **Camera Movement and Interaction**: Provides a player-controlled camera to explore rendered environments.
- **Collision Handling**: Implements distance-based collision response for fractal surfaces.

## Code Structure

```
Assets/Scripts/
├── AutoLoadPipelineAsset.cs
├── SDF/
│   ├── RaymarchManager.cs
│   ├── RaymarchShape.cs
│   ├── SDF.shader
│   ├── SDFRenderFeature.cs
├── Fractal/
│   ├── FollowCamera.cs
│   ├── FractalCollider.cs
│   ├── FractalRenderFeature.cs
│   ├── Player.cs
│   ├── Raymarching.shader
```

### Key Files

- **`AutoLoadPipelineAsset.cs`**: Automatically loads the specified URP asset at runtime.
- **`RaymarchManager.cs`**: Manages raymarching rendering and updates shader parameters dynamically.
- **`RaymarchShape.cs`**: Defines different geometric shapes and their transformations.
- **`SDF.shader`**: Core shader implementing signed distance function-based raymarching.
- **`SDFRenderFeature.cs`**: Custom URP render feature that applies raymarching in the render pipeline.
- **`FractalRenderFeature.cs`**: Handles rendering of fractal SDFs using raymarching.
- **`FractalCollider.cs`**: Provides distance-based collision detection and response for objects interacting with fractals.
- **`Player.cs`**: Implements first-person camera controls with movement and interaction.
- **`Raymarching.shader`**: Implements the fractal raymarching effect with color variation and fog effects.

## Setup and Usage

### Requirements

- Unity 6
- Universal Render Pipeline (URP)
- A graphics card capable of handling shader-based rendering

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/diegobus/MarchingBeyond.git
   ```
2. Open the project in Unity.
3. Open sample scene:
4. Play the scene and explore the procedural raymarched world!

## Controls

- **WASD**: Move forward/backward and strafe left/right
- **Mouse Movement**: Look around
- **Escape**: Unlock mouse cursor

## Customization

- Modify the **SDF.shader** and **Raymarching.shader** to experiment with different SDF primitives or fractals.
- Adjust shader properties in Unity's **Material Inspector** to tweak fractal appearance.
- Extend **RaymarchShape.cs** to add new shape types.
- Implement additional SDF operations such as smoothing, blending, or booleans.

## Credits

- Developed by: Julian and Diego
- Inspired by various raymarching and fractal rendering techniques.

## License

This project is open-source under the MIT License. Feel free to modify and distribute it for your own projects.
