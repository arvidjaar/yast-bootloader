/*
 * YaST2: Core system
 *
 * Description:
 *   YaST2 SCR: Prom agent implementation
 *
 * Authors:
 *   Thorsten Kukuk <kukuk@suse.de>
 *
 * $Id$
 */

#ifndef _PromAgent_h
#define _PromAgent_h

#undef y2log_component
#define y2log_component "ag_prom"
#include <Y2.h>
#include <scr/SCRAgent.h>
#include <scr/SCRInterpreter.h>

/**
 * @short An interface class between YaST2 and Prom Agent
 */
class PromAgent : public SCRAgent
{
    private:
        /**
         * Agent private variables
         */

    public:
        /**
         * Default constructor.
         */
        PromAgent();
        /** 
         * Destructor.
         */
        virtual ~PromAgent();

        /**
         * Provides SCR Read ().
         * @param path Path that should be read.
         * @param arg Additional parameter.
         */
        virtual YCPValue Read(const YCPPath &path, const YCPValue& arg = YCPNull());

        /**
         * Provides SCR Write ().
         */
        virtual YCPValue Write(const YCPPath &path, const YCPValue& value, const YCPValue& arg = YCPNull());

        /**
         * Provides SCR Write ().
         */
        virtual YCPValue Dir(const YCPPath& path);

        /**
         * Used for mounting the agent.
         */    
        virtual YCPValue otherCommand(const YCPTerm& term);
};

#endif /* _PromAgent_h */
