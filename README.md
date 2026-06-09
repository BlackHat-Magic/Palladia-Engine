<div align="center">

# Palladia Engine

(Formerly Asmadi)

A Simple, ECS-based game engine written in Zig using SDL3's GPU API

</div>

## Overview

The Palladia Engine is a game engine using SDL3's GPU API to create 3D accelerated graphical applications with Vulkan (and soon hopefully WebGPU). I might add Metal support if I feel like it.

> Note: Work on Palladia (namely the [Zig rewrite](https://github.com/BlackHat-Magic/Palladia-Engine/tree/rewrite/zig)) is paused to replace the existing MicroUI integration with [Slayer](https://github.com/BlackHat-Magic/Slayer), a flexible custom UI library. The Python prototype needs to be replaced with a Zig implementation.
>
> [Piru](https://github.com/BlackHat-Magic/Piru) may end up being the engine's scripting language (thoughit is not a blocker and will have to wait much longer).

### Goals

The main goal with this project was to learn graphics programming. In game development, I often find myself knowing exactly what I want the code to look like, but unsure of how to tell the game engine how to do that. So, I figured that several hundred to several thousand hours of trial and error should save me about thirty minutes of reading the Godot Documentation.

### Features

- Three.js-like API for creating simple geometries
- Random number generation and spline tools
- Premade Materials
- [ ] Character Controllers
- [ ] Physics
    - [ ] TinyPhysicsEngine-like soft body physics for embedded devices
    - [ ] SDF-based primitive-only collision system
    - [ ] Conventional primitive and mesh collision system with soft body support
- [ ] Lighting: point lights and ambient lights
- [ ] Performance Profiler
- [ ] Software Rasterizer
- [ ] Fixed-Point Software Rasterizer
