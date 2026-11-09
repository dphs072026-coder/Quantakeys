import 'package:quantakeys/models/key_item.dart';
import 'package:quantakeys/models/key_layout.dart';

class DefaultLayouts {
  static KeyLayout get abc => KeyLayout(
        name: 'ABC',
        rows: [
          // Top Number Row (converts to ! @ # $ % ^ & * ( ) on Shift/Caps Lock)
          ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'].map((s) => KeyItem(label: s, value: s, flex: 2)).toList(),
          // Top Alphabet Row
          ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'].map((s) => KeyItem(label: s, value: s, flex: 2)).toList(),
          // Middle Alphabet Row with 0.5-key Spaced Layout on 'a' row
          [
            KeyItem(label: '', value: '', flex: 1),
            ...['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'].map((s) => KeyItem(label: s, value: s, flex: 2)),
            KeyItem(label: '', value: '', flex: 1),
          ],
          // Bottom Alphabet Row with Enlarged Clear/Backspace Button
          [
            KeyItem(label: '⇧', value: 'SHIFT', type: KeyType.action, flex: 3),
            ...['z', 'x', 'c', 'v', 'b', 'n', 'm'].map((s) => KeyItem(label: s, value: s, flex: 2)),
            KeyItem(label: '⌫', value: 'BACKSPACE', type: KeyType.action, flex: 3),
          ],
          // Bottom Control Row
          [
            KeyItem(label: '?123', value: 'SYMB', type: KeyType.layoutSwitch, flex: 3),
            KeyItem(label: ',', value: ',', flex: 2),
            KeyItem(label: 'space', value: ' ', flex: 8),
            KeyItem(label: '.', value: '.', flex: 2),
            KeyItem(label: '⏎', value: '\n', type: KeyType.action, flex: 3),
          ]
        ],
      );

  static KeyLayout get symbols => KeyLayout(
        name: 'SYMB',
        rows: [
          ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'].map((s) => KeyItem(label: s, value: s)).toList(),
          ['₹', 'Rs', '\$', '€', '£', '¥', '@', '#', '%', '&'].map((s) => KeyItem(label: s, value: s)).toList(),
          ['-', '+', '(', ')', '/', '*', '"', "'", ':', ';'].map((s) => KeyItem(label: s, value: s)).toList(),
          [
            KeyItem(label: 'ABC', value: 'ABC', type: KeyType.layoutSwitch, flex: 2),
            ...['!', '?', '\\', '`', '~', '<', '>'].map((s) => KeyItem(label: s, value: s)),
            KeyItem(label: '⌫', value: 'BACKSPACE', type: KeyType.action, flex: 2),
          ],
          [
            KeyItem(label: '₹', value: '₹', flex: 2),
            KeyItem(label: ',', value: ',', flex: 2),
            KeyItem(label: 'space', value: ' ', flex: 6),
            KeyItem(label: '.', value: '.', flex: 2),
            KeyItem(label: '⏎', value: '\n', type: KeyType.action, flex: 2),
          ]
        ],
      );

  static KeyLayout get math => KeyLayout(
        name: 'MATH',
        rows: [
          [
            KeyItem(label: '+', value: '+', shortcut: 'q'),
            KeyItem(label: '-', value: '-', shortcut: 'w'),
            KeyItem(label: '×', value: '×', shortcut: 'e'),
            KeyItem(label: '÷', value: '÷', shortcut: 'r'),
            KeyItem(label: '=', value: '=', shortcut: 't'),
            KeyItem(label: '≠', value: '≠', shortcut: 'y'),
            KeyItem(label: '<', value: '<', shortcut: 'u'),
            KeyItem(label: '>', value: '>', shortcut: 'i'),
            KeyItem(label: '≤', value: '≤', shortcut: 'o'),
            KeyItem(label: '≥', value: '≥', shortcut: 'p'),
          ],
          [
            KeyItem(label: '√', value: '√', shortcut: 'a'),
            KeyItem(label: '∛', value: '∛', shortcut: 's'),
            KeyItem(label: '∜', value: '∜', shortcut: 'd'),
            KeyItem(label: 'π', value: 'π', shortcut: 'f'),
            KeyItem(label: 'e', value: 'e', shortcut: 'g'),
            KeyItem(label: 'φ', value: 'φ', shortcut: 'h'),
            KeyItem(label: '∞', value: '∞', shortcut: 'j'),
            KeyItem(label: '%', value: '%', shortcut: 'k'),
            KeyItem(label: '^', value: '^', shortcut: 'l'),
            KeyItem(label: '°', value: '°', shortcut: ';'),
          ],
          [
            KeyItem(label: '∫', value: '∫', shortcut: 'z'),
            KeyItem(label: '∬', value: '∬', shortcut: 'x'),
            KeyItem(label: '∑', value: '∑', shortcut: 'c'),
            KeyItem(label: '∏', value: '∏', shortcut: 'v'),
            KeyItem(label: '±', value: '±', shortcut: 'b'),
            KeyItem(label: '∓', value: '∓', shortcut: 'n'),
            KeyItem(label: '∝', value: '∝', shortcut: 'm'),
            KeyItem(label: '≈', value: '≈', shortcut: ','),
            KeyItem(label: '≅', value: '≅', shortcut: '.'),
            KeyItem(label: '≡', value: '≡', shortcut: '/'),
          ],
          [
            KeyItem(label: '∀', value: '∀', shortcut: '1'),
            KeyItem(label: '∃', value: '∃', shortcut: '2'),
            KeyItem(label: '¬', value: '¬', shortcut: '3'),
            KeyItem(label: '∧', value: '∧', shortcut: '4'),
            KeyItem(label: '∨', value: '∨', shortcut: '5'),
            KeyItem(label: '⊕', value: '⊕', shortcut: '6'),
            KeyItem(label: '⊗', value: '⊗', shortcut: '7'),
            KeyItem(label: '⊥', value: '⊥', shortcut: '8'),
            KeyItem(label: '⌫', value: 'BACKSPACE', type: KeyType.action, flex: 2),
          ],
          [
            KeyItem(label: 'ABC', value: 'ABC', type: KeyType.layoutSwitch, flex: 2),
            KeyItem(label: '( )', value: '()', shortcut: '9'),
            KeyItem(label: 'space', value: ' ', flex: 4),
            KeyItem(label: '[ ]', value: '[]', shortcut: '0'),
            KeyItem(label: 'lim', value: 'lim'),
          ],
        ],
      );

  static KeyLayout get chem => KeyLayout(
        name: 'CHEM',
        rows: [
          [
            KeyItem(label: '→', value: '→', shortcut: 'q'),
            KeyItem(label: '⇌', value: '⇌', shortcut: 'w'),
            KeyItem(label: '↔', value: '↔', shortcut: 'e'),
            KeyItem(label: '∆', value: '∆', shortcut: 'r'),
            KeyItem(label: '‡', value: '‡', shortcut: 't'),
            KeyItem(label: '⬡', value: '⬡', shortcut: 'y'),
            KeyItem(label: '⌬', value: '⌬', shortcut: 'u'),
            KeyItem(label: '∗', value: '∗', shortcut: 'i'),
            KeyItem(label: '·', value: '·', shortcut: 'o'),
            KeyItem(label: 'atm', value: 'atm', shortcut: 'p'),
          ],
          [
            KeyItem(label: '₀', value: '₀', shortcut: 'a'),
            KeyItem(label: '₁', value: '₁', shortcut: 's'),
            KeyItem(label: '₂', value: '₂', shortcut: 'd'),
            KeyItem(label: '₃', value: '₃', shortcut: 'f'),
            KeyItem(label: '₄', value: '₄', shortcut: 'g'),
            KeyItem(label: '₅', value: '₅', shortcut: 'h'),
            KeyItem(label: '₆', value: '₆', shortcut: 'j'),
            KeyItem(label: '₇', value: '₇', shortcut: 'k'),
            KeyItem(label: '₈', value: '₈', shortcut: 'l'),
            KeyItem(label: '₉', value: '₉', shortcut: ';'),
          ],
          [
            KeyItem(label: '⁰', value: '⁰', shortcut: 'z'),
            KeyItem(label: '¹', value: '¹', shortcut: 'x'),
            KeyItem(label: '²', value: '²', shortcut: 'c'),
            KeyItem(label: '³', value: '³', shortcut: 'v'),
            KeyItem(label: '⁴', value: '⁴', shortcut: 'b'),
            KeyItem(label: '⁵', value: '⁵', shortcut: 'n'),
            KeyItem(label: '⁶', value: '⁶', shortcut: 'm'),
            KeyItem(label: '⁷', value: '⁷', shortcut: ','),
            KeyItem(label: '⁸', value: '⁸', shortcut: '.'),
            KeyItem(label: '⁹', value: '⁹', shortcut: '/'),
          ],
          [
            KeyItem(label: 'aq', value: 'aq', shortcut: '1'),
            KeyItem(label: 'g', value: 'g', shortcut: '2'),
            KeyItem(label: 'l', value: 'l', shortcut: '3'),
            KeyItem(label: 's', value: 's', shortcut: '4'),
            KeyItem(label: '+', value: '+', shortcut: '5'),
            KeyItem(label: '-', value: '-', shortcut: '6'),
            KeyItem(label: '(', value: '(', shortcut: '7'),
            KeyItem(label: ')', value: ')', shortcut: '8'),
            KeyItem(label: '⌫', value: 'BACKSPACE', type: KeyType.action, flex: 3),
          ],
          [
            KeyItem(label: 'P', value: 'P'),
            KeyItem(label: 'V', value: 'V'),
            KeyItem(label: 'T', value: 'T'),
            KeyItem(label: 'space', value: ' ', flex: 5),
            KeyItem(label: '⏎', value: '\n', type: KeyType.action, flex: 2),
          ],
        ],
      );

  static KeyLayout get phys => KeyLayout(
        name: 'PHYS',
        rows: [
          [
            KeyItem(label: 'α', value: 'α', shortcut: 'q'),
            KeyItem(label: 'β', value: 'β', shortcut: 'w'),
            KeyItem(label: 'γ', value: 'γ', shortcut: 'e'),
            KeyItem(label: 'δ', value: 'δ', shortcut: 'r'),
            KeyItem(label: 'ε', value: 'ε', shortcut: 't'),
            KeyItem(label: 'ζ', value: 'ζ', shortcut: 'y'),
            KeyItem(label: 'η', value: 'η', shortcut: 'u'),
            KeyItem(label: 'θ', value: 'θ', shortcut: 'i'),
            KeyItem(label: 'λ', value: 'λ', shortcut: 'o'),
            KeyItem(label: 'μ', value: 'μ', shortcut: 'p'),
          ],
          [
            KeyItem(label: 'ν', value: 'ν', shortcut: 'a'),
            KeyItem(label: 'ξ', value: 'ξ', shortcut: 's'),
            KeyItem(label: 'π', value: 'π', shortcut: 'd'),
            KeyItem(label: 'ρ', value: 'ρ', shortcut: 'f'),
            KeyItem(label: 'σ', value: 'σ', shortcut: 'g'),
            KeyItem(label: 'τ', value: 'τ', shortcut: 'h'),
            KeyItem(label: 'φ', value: 'φ', shortcut: 'j'),
            KeyItem(label: 'ψ', value: 'ψ', shortcut: 'k'),
            KeyItem(label: 'ω', value: 'ω', shortcut: 'l'),
            KeyItem(label: 'Δ', value: 'Δ', shortcut: ';'),
          ],
          [
            KeyItem(label: '∇', value: '∇', shortcut: 'z'),
            KeyItem(label: '∂', value: '∂', shortcut: 'x'),
            KeyItem(label: '∫', value: '∫', shortcut: 'c'),
            KeyItem(label: '∮', value: '∮', shortcut: 'v'),
            KeyItem(label: '⟨', value: '⟨', shortcut: 'b'),
            KeyItem(label: '|', value: '|', shortcut: 'n'),
            KeyItem(label: '⟩', value: '⟩', shortcut: 'm'),
            KeyItem(label: '†', value: '†', shortcut: ','),
            KeyItem(label: '°', value: '°', shortcut: '.'),
            KeyItem(label: '·', value: '·', shortcut: '/'),
          ],
          [
            KeyItem(label: 'i→', value: 'i→', shortcut: '1'),
            KeyItem(label: 'j→', value: 'j→', shortcut: '2'),
            KeyItem(label: 'k→', value: 'k→', shortcut: '3'),
            KeyItem(label: 'x→', value: 'x→', shortcut: '4'),
            KeyItem(label: 'v→', value: 'v→', shortcut: '5'),
            KeyItem(label: 'a→', value: 'a→', shortcut: '6'),
            KeyItem(label: 'F→', value: 'F→', shortcut: '7'),
            KeyItem(label: 'p→', value: 'p→', shortcut: '8'),
            KeyItem(label: '⌫', value: 'BACKSPACE', type: KeyType.action, flex: 2),
          ],
          [
            KeyItem(label: 'ABC', value: 'ABC', type: KeyType.layoutSwitch, flex: 2),
            KeyItem(label: 'E→', value: 'E→'),
            KeyItem(label: 'B→', value: 'B→'),
            KeyItem(label: 'Ω', value: 'Ω'),
            KeyItem(label: 'space', value: ' ', flex: 4),
            KeyItem(label: '⏎', value: '\n', type: KeyType.action, flex: 2),
          ],
        ],
      );

  static KeyLayout get trig => KeyLayout(
        name: 'TRIG',
        rows: [
          ['sin', 'cos', 'tan', 'asin', 'acos', 'atan', '(', ')', '[', ']'].map((s) => KeyItem(label: s, value: s.length == 1 ? s : '$s(')).toList(),
          ['sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh', 'exp', 'log', 'ln', 'abs'].map((s) => KeyItem(label: s, value: '$s(')).toList(),
          ['!', 'avg', 'sum', 'min', 'max', 'mod', 'π', 'e', '√', '^'].map((s) => KeyItem(label: s, value: (s == '!' || s == 'π' || s == 'e' || s == '^' || s == '√') ? s : '$s(')).toList(),
          [
            ...['1', '2', '3', '4', '5', '6', '7', '8'].map((s) => KeyItem(label: s, value: s)),
            KeyItem(label: '⌫', value: 'BACKSPACE', type: KeyType.action, flex: 3),
          ],
          [
            ...['9', '0', '.', ','].map((s) => KeyItem(label: s, value: s)),
            KeyItem(label: 'space', value: ' ', flex: 5),
            KeyItem(label: '⏎', value: '\n', type: KeyType.action, flex: 2),
          ],
        ],
      );

  static KeyLayout get custom => KeyLayout(
        name: 'NUM',
        rows: [
          ['7', '8', '9', '/'].map((s) => KeyItem(label: s, value: s)).toList(),
          ['4', '5', '6', '*'].map((s) => KeyItem(label: s, value: s)).toList(),
          ['1', '2', '3', '-'].map((s) => KeyItem(label: s, value: s)).toList(),
          ['0', '.', '=', '+'].map((s) => KeyItem(label: s, value: s)).toList(),
          [
            KeyItem(label: 'ABC', value: 'ABC', type: KeyType.layoutSwitch),
            KeyItem(label: '⌫', value: 'BACKSPACE', type: KeyType.action, flex: 3),
          ]
        ],
      );
}
