# Mixin lwtk.Node


## Contents

   * [Inheritance](#inheritance)
   * [Methods](#methods)
      * [discard()](#.discard) - Discard Node that should no longer be used.
   * [Subclasses](#subclasses)


## Inheritance
   * / **[Object](../lwtk/Object.md#inheritance)** /
        * [Actionable](../lwtk/Actionable.md#inheritance) / _`Node`_
        * **[Application](../lwtk/Application.md#inheritance)** / _`Node`_

## Methods
   * <span id=".discard">**`Node:discard()`**</span>

     Discard Node that should no longer be used.
     
     This function could be useful under Lua 5.1 which does not have ephemeron tables.


## Subclasses
   * / **[Object](../lwtk/Object.md#subclasses)** /
        * [Actionable](../lwtk/Actionable.md#subclasses) / _`Node`_ / [Drawable](../lwtk/Drawable.md#subclasses) /
             * **[Component](../lwtk/Component.md#subclasses)** /
                  * [Compound](../lwtk/Compound.md#subclasses) / **[InnerCompound](../lwtk/InnerCompound.md#inheritance)**
                  * [Styleable](../lwtk/Styleable.md#subclasses) / [Animatable](../lwtk/Animatable.md#subclasses) / **[Widget](../lwtk/Widget.md#subclasses)** / [Compound](../lwtk/Compound.md#subclasses) /
                       * [LayoutFrame](../lwtk/LayoutFrame.md#subclasses) / [Control](../lwtk/Control.md#subclasses) /
                            * [Focusable](../lwtk/Focusable.md#subclasses) / **[TextInput](../lwtk/TextInput.md#inheritance)**
                            * [HotkeyListener](../lwtk/HotkeyListener.md#subclasses) / **[Button](../lwtk/Button.md#subclasses)** /
                                 * [Focusable](../lwtk/Focusable.md#subclasses) / **[PushButton](../lwtk/PushButton.md#inheritance)**
                                 * **[TextLabel](../lwtk/TextLabel.md#subclasses)** / **[TitleText](../lwtk/TitleText.md#inheritance)**
                       * [MouseDispatcher](../lwtk/MouseDispatcher.md#subclasses) / **[Group](../lwtk/Group.md#subclasses)** /
                            * [Colored](../lwtk/Colored.md#subclasses) / **[ViewSwitcher](../lwtk/ViewSwitcher.md#inheritance)**
                            * **[Column](../lwtk/Column.md#inheritance)**
                            * [LayoutFrame](../lwtk/LayoutFrame.md#subclasses) / [Control](../lwtk/Control.md#subclasses) / **[Box](../lwtk/Box.md#subclasses)** / [Focusable](../lwtk/Focusable.md#subclasses) / **[FocusGroup](../lwtk/FocusGroup.md#inheritance)**
                            * **[Matrix](../lwtk/Matrix.md#inheritance)**
                            * **[Row](../lwtk/Row.md#inheritance)**
                            * **[Space](../lwtk/Space.md#inheritance)**
                            * **[Square](../lwtk/Square.md#inheritance)**
                  * **[TextCursor](../lwtk/TextCursor.md#inheritance)**
                  * **[TextFragment](../lwtk/TextFragment.md#inheritance)**
             * [Styleable](../lwtk/Styleable.md#subclasses) / [KeyHandler](../lwtk/KeyHandler.md#subclasses) / [MouseDispatcher](../lwtk/MouseDispatcher.md#subclasses) / **[Window](../lwtk/Window.md#inheritance)**
        * **[Application](../lwtk/Application.md#subclasses)** / _`Node`_ / [MouseDispatcher](../lwtk/MouseDispatcher.md#subclasses) / **[love.Application](../lwtk/love/Application.md#inheritance)**

