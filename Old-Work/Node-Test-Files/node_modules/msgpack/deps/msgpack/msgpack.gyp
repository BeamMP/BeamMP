{
	"targets": [
		{
				'target_name': 'libmsgpack',
				'include_dirs': [ '.' ],
				'type': 'static_library',
				'sources': [
					'objectc.c',
					'unpack.c',
					'vrefbuffer.c',
					'zone.c',
					'version.c'					
				],
				'cflags_cc': [
					'-Wall',
					'-O3'
				],
				'cflags': [
					'-Wall',
					'-O3'
				],
				'cflags!': [
          '-fno-exceptions',
          '-Wno-unused-function'
        ],
				'cflags_cc!': [
          '-fno-exceptions',
          '-Wno-unused-function'
        ],
				'conditions': [
          ['OS=="mac"', {
            'configurations': {                                                 
              'Debug': {       
                'xcode_settings': {
                  'GCC_ENABLE_CPP_EXCEPTIONS': 'YES',
                  'WARNING_CFLAGS': ['-Wall', '-Wno-unused-function'],
                }
              },
              'Release': {
                'xcode_settings': {
                  'GCC_ENABLE_CPP_EXCEPTIONS': 'YES',
                  'WARNING_CFLAGS': ['-Wall', '-Wno-unused-function'],
                },
              },
            },
          }],
					['OS=="win"', {
						'configurations': {
							'Debug': {
								'msvs_settings': {
									'VCCLCompilerTool': {
										'CompileAs': '2',
										'ExceptionHandling': '1',
									},
								},
							},
							'Release': {
								'msvs_settings': {
									'VCCLCompilerTool': {
										'CompileAs': '2',
										'ExceptionHandling': '1',
									},
								},
							},
						},
					}]
				]
			},
	]
}
