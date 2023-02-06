# Changelog

All notable changes to this project will be documented in this file.

## 0.9.0 - 2023-02-06

- Subclass Milemarker to ensure that PushMetrics will work with the entire
  Milemarker API

- Use a clever approach to dynamic subclassing to generate PushMetrics classes
  that subclass a different Milemarker subclass, and allow injecting a
  different Milemarker implementation for testing. In the future, if we simply
  the public Milemarker API we may be able to go back to delegating.

## 0.0.1 - 2023-01-27

- Extract PushMarker as a separate gem from
  https://github.com/hathitrust/holdings-backend


