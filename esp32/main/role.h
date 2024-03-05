#ifndef FILE_role_SEEN
#define FILE_role_SEEN

// #define ROLE 'F'
#define ROLE 'G'

#ifndef ROLE
    I am using syntax error to denote undefined macro here!
#endif
#if ROLE == 'G'
    #define ROLE_GLOVE_WHICH 'L'
    // #define ROLE_GLOVE_WHICH 'R'
#endif

#endif
