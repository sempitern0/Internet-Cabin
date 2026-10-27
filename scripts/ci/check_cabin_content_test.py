#!/usr/bin/env python3
"""Mutation regressions for the content authoring gate."""
import copy
import json
import unittest
from check_cabin_content import ROOT, validate


class ContentValidationTests(unittest.TestCase):
    def setUp(self):
        self.map = json.loads((ROOT / "game/adventure/cabin_map.json").read_text())
        self.items = json.loads((ROOT / "game/inventory/cabin_items.json").read_text())

    def test_authored_content(self):
        self.assertEqual(validate(self.map, self.items), [])

    def test_broken_authoring(self):
        mutations = [
            lambda d: d['pages'].append(copy.deepcopy(d['pages'][0])),
            lambda d: d['pages'][0].update(back_target='missing'),
            lambda d: d['pages'][0]['hotspots'][0].update(rect=[0, 0, 2, 1]),
            lambda d: d['pages'][0]['hotspots'][0].update(polygon=[[0, 0]]),
            lambda d: d['pages'][0]['hotspots'][0].update(action={'consume_item': True}),
            lambda d: d['pages'][0]['hotspots'][0].update(
                visible_when=['a'], hidden_when=['a']),
        ]
        for mutation in mutations:
            data = copy.deepcopy(self.map)
            mutation(data)
            with self.subTest(mutation=mutation):
                self.assertTrue(validate(data, self.items))

    def test_bad_item(self):
        self.items['items'][0]['start']['page'] = 'missing'
        self.assertTrue(validate(self.map, self.items))


if __name__ == '__main__':
    unittest.main()
