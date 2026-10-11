import unittest
from report_suitability import report


def fixture():
    rows = []
    for label, count in [('residue', 30), ('keyboard', 10), ('lighter', 10),
                         ('portrait', 10), ('empty', 20)]:
        for i in range(count):
            key = f'{label}-{i}'
            rows.append(dict(sha256=key, groupId=key, split='validation',
                             label=label, candidateStatus='supported' if label == 'residue'
                             else 'unsuitable'))
    return dict(rows=rows, complete=True, evidenceAuditPassed=True)


class ReportTest(unittest.TestCase):
    def test_all_uncertain_is_not_success(self):
        doc = fixture()
        for row in doc['rows']:
            if row['label'] == 'residue':
                row['candidateStatus'] = 'uncertain'
        result = report(doc)
        self.assertFalse(result['releaseGatePassed'])
        self.assertEqual(result['groups']['residue']['supportedGroupRate'], 0)
        self.assertEqual(result['groups']['residue']['groupSuccessRate'], 1)
        self.assertEqual(result['groups']['residue']['nonBlockedNonErrorGroups'], 30)

    def test_limited_uncertainty_is_silent_but_not_recognition(self):
        doc = fixture()
        for row in doc['rows'][:6]:
            row['candidateStatus'] = 'uncertain'
        result = report(doc)
        self.assertTrue(result['releaseGatePassed'])
        self.assertEqual(result['groups']['residue']['supportedGroupRate'], .8)
        self.assertEqual(result['groups']['residue']['groupSuccessRate'], 1)
        doc['rows'][6]['candidateStatus'] = 'uncertain'
        self.assertFalse(report(doc)['releaseGatePassed'])

    def test_one_false_reject_fails_even_above_95_percent(self):
        doc = fixture()
        doc['rows'][0]['candidateStatus'] = 'residueFree'
        self.assertFalse(report(doc)['releaseGatePassed'])

    def test_missing_category_and_unaudited_evidence_fail(self):
        doc = fixture()
        self.assertTrue(report(doc)['releaseGatePassed'])
        del doc['evidenceAuditPassed']
        self.assertFalse(report(doc)['releaseGatePassed'])
        doc['evidenceAuditPassed'] = True
        doc['rows'] = [r for r in doc['rows'] if r['label'] != 'lighter']
        self.assertFalse(report(doc)['releaseGatePassed'])

    def test_errors_and_split_leak_are_not_success(self):
        doc = fixture()
        doc['rows'][-1]['candidateStatus'] = 'error'
        self.assertFalse(report(doc)['releaseGatePassed'])
        doc['rows'].append(dict(doc['rows'][0], sha256='new', split='calibration'))
        with self.assertRaises(ValueError):
            report(doc)


if __name__ == '__main__':
    unittest.main()
