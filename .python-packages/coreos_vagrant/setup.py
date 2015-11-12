from setuptools import setup

setup(
    name='coreos-vagrant',
    version='0.1.0',
    py_modules=['coreos_vagrant'],
    include_package_data=True,
    install_requires=[
        'click',
    ],
    entry_points='''
        [console_scripts]
        coreos=coreos_vagrant:cli
    ''',
)