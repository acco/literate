## Test markdown

Both of our template files start off at the top with the declaration:

{lang='ruby'}
    i = []

For both, we'll start off with two operations defined in version one. We'll actually define one operation twice to see how it handles that.

In version two, we modify one operation and then add a new one.

### Template 1 version 1

{lang='ruby',name='operation_1',template='template1',ver='1'}
    1#not-rendered-when-rc-present
    i << ['valid1.1.1']

{lang='ruby',name='operation_2',template='template1',ver='1'}
    i << ['invalid1.2.1']

We redefine it:

{lang='ruby',name='operation_2',template='template1',ver='1'}
    i << ['valid1.2.1']

Final result of `i` should be `['valid1.1.1', 'valid1.2.1']`.

### Template 2 version 1

{lang='ruby',name='operation_1',template='template2',ver='1'}
    i << ['valid2.1.1']

{lang='ruby',name='operation_2',template='template2',ver='1'}
    i << ['invalid2.2.1']

We redefine it:

{lang='ruby',name='operation_2',template='template2',ver='1'}
    i << ['valid2.2.1']

Final result of `i` should be `['valid2.1.1', 'valid2.2.1']`.

### Template 1 version 2

Modify:

{lang='ruby',name='operation_1',template='template1',ver='2'}
    i << ['valid1.1.2']

Insert:

{lang='ruby',name='operation_3',template='template1',ver='2'}
    i << ['valid1.3.2']

Final result of `i` should be `['valid1.1.2', 'valid1.2.1', 'valid1.3.2']`.

### Template 2 version 2

Modify:

{lang='ruby',name='operation_1',template='template2',ver='2'}
    i << ['valid2.1.2']

Insert:

{lang='ruby',name='operation_3',template='template2',ver='2'}
    i << ['valid2.3.2']

Final result of `i` should be `['valid2.1.2', 'valid2.2.1', 'valid2.3.2']`.
