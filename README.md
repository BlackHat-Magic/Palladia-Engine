<div align="center">

# Palladia Engine

(Formerly Asmadi)

A Simple, ECS-based game engine written in C using SDL3's GPU API

</div>

## Overview

The Asmadi Palladia Engine is a game engine using SDL3's GPU API to create 3D accelerated graphical applications with Vulkan (and soon hopefully WebGPU). I might add Metal support if I feel like it.

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

TODO: Billboard component
